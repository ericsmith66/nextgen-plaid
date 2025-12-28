require "json"
require "open3"
require "tempfile"
require "securerandom"

module SapAgent
  COMMAND_MAPPING = {
    "generate" => SapAgent::GenerateCommand,
    "qa" => SapAgent::QaCommand,
    "debug" => SapAgent::DebugCommand,
    "health" => SapAgent::HealthCommand
  }.freeze

  class << self
    attr_accessor :task_id, :branch, :correlation_id, :model_used

    def process(query_type, payload)
      command_class = COMMAND_MAPPING[query_type.to_s]
      raise "Unknown query type: #{query_type}" unless command_class

      command_class.new(payload).execute
    end

    def code_review(branch: nil, files: nil, task_id: nil, correlation_id: SecureRandom.uuid)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      self.task_id = task_id
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      selected_files = files.presence || diff_files(branch)
      filtered_files = prioritize_files(selected_files).take(5)

      log_review_event("code_review.start", files: filtered_files)

      contents = fetch_contents(filtered_files)
      token_count = estimate_tokens(contents.values.join("\n"))

      if token_count > SapAgent::Config::TOKEN_BUDGET
        log_review_event("code_review.abort", reason: "token_budget_exceeded", token_count: token_count)
        return { error: "Budget exceeded", token_count: token_count }
      end

      score = 100
      offenses = []
      begin
        offenses = run_rubocop(filtered_files)
        offenses = offenses.first(SapAgent::Config::OFFENSE_LIMIT)
        score = [ 100 - (offenses.size * 5), 0 ].max
      rescue StandardError => e
        log_review_event("code_review.rubocop_error", error: e.message)
      end

      if score < SapAgent::Config::SCORE_ESCALATE_THRESHOLD || token_count > 500
        self.model_used = ENV["ESCALATE_LLM"].presence || SapAgent::Config::MODEL_ESCALATE
      end

      redacted_contents = contents.transform_values { |val| SapAgent::Redactor.redact(val) }
      output = build_output(offenses, redacted_contents)

      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_review_event("code_review.complete", score: score, elapsed_ms: elapsed, model_used: model_used)

      output
    end

    def iterate_prompt(task:, branch: nil, correlation_id: SecureRandom.uuid, resume_token: nil, human_feedback: nil, pause: false)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      self.task_id = task
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      context = [ "Task: #{task}" ]
      context << "Human feedback: #{human_feedback}" if human_feedback.present?

      if pause
        token = resume_token.presence || SecureRandom.uuid
        log_iterate_event("iterate.paused", resume_token: token)
        return { status: "paused", resume_token: token, context: context.join("\n") }
      end

      iterations = []
      retry_count = 0
      current_resume_token = resume_token

      SapAgent::Config::ITERATION_CAP.times do |idx|
        iteration_number = idx + 1
        current_model = self.model_used
        output = generate_iteration_output(context.join("\n"), iteration_number, current_model)
        iterations << { iteration: iteration_number, output: output, model_used: current_model }

        token_count = estimate_tokens(context.join("\n") + output.to_s)
        if token_count > SapAgent::Config::TOKEN_BUDGET
          log_iterate_event("iterate.abort", reason: "token_budget_exceeded", token_count: token_count, iteration: iteration_number)
          return { status: "aborted", reason: "token_budget_exceeded", token_count: token_count, iterations: iterations, partial_output: output }
        end

        score = score_output(output, context.join("\n"))
        log_iterate_event("iterate.phase", iteration: iteration_number, score: score, token_count: token_count, model_used: current_model)

        context << "Iteration #{iteration_number} output: #{output}"

        if score >= SapAgent::Config::SCORE_STOP_THRESHOLD
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          log_iterate_event("iterate.complete", iteration: iteration_number, score: score, elapsed_ms: elapsed, model_used: current_model)
          return { status: "completed", iterations: iterations, final_output: output, score: score, model_used: current_model, resume_token: current_resume_token }
        end

        if score < SapAgent::Config::SCORE_ESCALATE_THRESHOLD || token_count > 500
          self.model_used = ENV["ESCALATE_LLM"].presence || SapAgent::Config::MODEL_ESCALATE
        end

        if retry_count < SapAgent::Config::BACKOFF_MS.size
          sleep(SapAgent::Config::BACKOFF_MS[retry_count] / 1000.0)
          retry_count += 1
        else
          log_iterate_event("iterate.abort", reason: "iteration_cap", iteration: iteration_number)
          return { status: "aborted", reason: "iteration_cap", iterations: iterations, final_output: output, score: score, model_used: current_model, resume_token: current_resume_token }
        end
      end

      { status: "aborted", reason: "iteration_cap", iterations: iterations, model_used: self.model_used, resume_token: current_resume_token }
    rescue StandardError => e
      log_iterate_event("iterate.error", error: e.message)
      { status: "error", error: e.message, iterations: iterations }
    end
    def sync_backlog
      backlog_path = Rails.root.join("knowledge_base/backlog.json")
      todo_path = Rails.root.join("TODO.md")

      backlog = File.exist?(backlog_path) ? JSON.parse(File.read(backlog_path)) : []

      todo_content = "# NextGen Plaid — TODO\n\n"

      done = backlog.select { |i| i["status"] == "Completed" }
      todo = backlog.select { |i| i["status"] != "Completed" }

      todo_content << "## Next\n"
      todo.each do |item|
        todo_content << "- [ ] #{item["title"]} (#{item["id"]}) - #{item["priority"]}\n"
      end

      todo_content << "\n## Done ✅\n"
      done.each do |item|
        todo_content << "- #{item["title"]} (#{item["id"]})\n"
      end

      File.write(todo_path, todo_content)
      Rails.logger.info({ event: "sap.backlog.synced", todo_count: todo.size, done_count: done.size }.to_json)
    end

    def update_backlog(item_data)
      SapAgent::BacklogStrategy.store!(item_data)
      sync_backlog
    end

    def prune_backlog
      backlog_path = Rails.root.join("knowledge_base/backlog.json")
      archive_path = Rails.root.join("knowledge_base/backlog_archive.json")
      return unless File.exist?(backlog_path)

      backlog = JSON.parse(File.read(backlog_path))
      archive = File.exist?(archive_path) ? JSON.parse(File.read(archive_path)) : []

      pruned = []
      kept = []

      backlog.each do |item|
        if item["priority"] != "High" && item["status"] != "Completed"
          kept << item
        else
          kept << item
        end
      end

      if pruned.any?
        archive += pruned
        File.write(backlog_path, JSON.pretty_generate(kept))
        File.write(archive_path, JSON.pretty_generate(archive))
        sync_backlog
        Rails.logger.info({ event: "sap.backlog.pruned", count: pruned.size }.to_json)
      end
    end

    def decompose(task_id, user_id, query)
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "SAP",
        action: "DECOMPOSE_START",
        details: "Starting decomposition for query: #{query}"
      )

      result = process("generate", { query: query, user_id: user_id })
      prd_content = result[:response]

      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "SAP",
        action: "DECOMPOSE_SUCCESS",
        details: "Generated PRD: #{prd_content[0..200]}..."
      )

      AgentQueueJob.set(queue: :sap_to_cwa).perform_later(task_id, {
        prd: prd_content,
        user_id: user_id
      })
    rescue StandardError => e
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "SAP",
        action: "DECOMPOSE_FAILURE",
        details: e.message
      )
      raise e
    end

    private

    def diff_files(branch)
      base_ref = branch || "HEAD"
      stdout, = Open3.capture3("git", "diff", "--name-only", base_ref)
      files = stdout.to_s.split("\n").map(&:strip).reject(&:empty?)
      files.reject { |f| f.match?(/\.(bin|jpg|png|gif|jpeg)$/i) }
    rescue StandardError => e
      log_review_event("code_review.diff_fallback", error: e.message)
      files || []
    end

    def prioritize_files(files)
      priority = lambda do |path|
        return 0 if path.start_with?("app/models")
        return 1 if path.start_with?("app/services")
        return 2 if path.start_with?("spec") || path.start_with?("test")

        3
      end

      files.sort_by { |f| [ priority.call(f), f.length ] }
    end

    def fetch_contents(files)
      files.each_with_object({}) do |file, memo|
        memo[file] = File.read(Rails.root.join(file))
      rescue StandardError => e
        log_review_event("code_review.fetch_error", file: file, error: e.message)
      end
    end

    def run_rubocop(files)
      return [] if files.empty?

      stdout = ""
      stderr = ""
      status = nil
      cmd = [
        "bundle", "exec", "rubocop",
        "--format", "json",
        "--fail-level", "E",
        "--only", "Lint,Security,Style",
        "--config", Rails.root.join("config/rubocop.yml").to_s,
        *files
      ]

      SapAgent::TimeoutWrapper.with_timeout(SapAgent::Config::RUBOCOP_TIMEOUT_SECONDS) do
        stdout, stderr, status = Open3.capture3(*cmd)
      end

      log_review_event("code_review.rubocop_stderr", stderr: stderr.strip) unless stderr.to_s.strip.empty?
      return [] unless status&.success?

      data = JSON.parse(stdout)
      offenses = data.fetch("files", []).flat_map { |f| f["offenses"] }
      offenses.first(SapAgent::Config::OFFENSE_LIMIT).map do |offense|
        {
          "offense" => offense["message"],
          "line" => offense.dig("location", "start_line")
        }
      end
    rescue Timeout::Error
      log_review_event("code_review.rubocop_timeout", timeout_seconds: SapAgent::Config::RUBOCOP_TIMEOUT_SECONDS)
      raise
    rescue StandardError => e
      log_review_event("code_review.rubocop_error", error: e.message)
      []
    end

    def build_output(offenses, contents)
      {
        "strengths" => [ "Reviewed #{contents.keys.size} files" ],
        "weaknesses" => offenses.empty? ? [] : [ "Found #{offenses.size} RuboCop offenses" ],
        "issues" => offenses,
        "recommendations" => offenses.map { |o| "Address: #{o["offense"]} (line #{o["line"]})" },
        "files" => contents
      }
    end

    def log_review_event(event, data = {})
      payload = {
        timestamp: Time.now.utc.iso8601,
        task_id: task_id,
        branch: branch,
        uuid: SecureRandom.uuid,
        correlation_id: correlation_id,
        model_used: model_used,
        elapsed_ms: data.delete(:elapsed_ms),
        score: data.delete(:score)
      }.merge(data).merge(event: event).compact

      logger.info(payload.to_json)
    end

    def log_iterate_event(event, data = {})
      payload = {
        timestamp: Time.now.utc.iso8601,
        task_id: task_id,
        branch: branch,
        uuid: SecureRandom.uuid,
        correlation_id: correlation_id,
        model_used: model_used,
        elapsed_ms: data.delete(:elapsed_ms),
        score: data.delete(:score)
      }.merge(data).merge(event: event).compact

      logger.info(payload.to_json)
    end

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end

    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end

    def score_output(output, context)
      # Default heuristic score; tests will stub this method for deterministic behavior.
      length_score = [ (output.to_s.length + context.to_s.length) / 10, 100 ].min
      [ length_score, SapAgent::Config::SCORE_STOP_THRESHOLD ].min
    end

    def generate_iteration_output(context, iteration_number, model)
      "Iteration #{iteration_number} response using #{model}: #{context[0..50]}"
    end
  end
end
