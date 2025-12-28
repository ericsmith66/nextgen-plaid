require "json"
require "open3"
require "tempfile"

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

    def estimate_tokens(text)
      (text.to_s.length / 4.0).ceil
    end

    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end
  end
end
