require "json"
require "open3"
require "tempfile"
require "securerandom"
require "fileutils"

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

      result = command_class.new(payload).execute

      if result.is_a?(Hash) && result[:response].present? && !result[:response].include?("[CONTEXT START]")
        prefix = SapAgent::RagProvider.build_prefix(query_type, payload[:user_id] || payload["user_id"])
        result = result.merge(response: "#{prefix}\n\n#{result[:response]}")
      end

      result
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

    def adaptive_iterate(task:, branch: nil, correlation_id: SecureRandom.uuid, human_feedback: nil, start_model: nil)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      self.task_id = task
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = start_model.presence || ENV["ESCALATE_LLM"].presence || SapAgent::Config::MODEL_DEFAULT

      context = [ "Task: #{task}" ]
      context << "Human feedback: #{human_feedback}" if human_feedback.present?

      iterations = []
      retry_count = 0
      escalation_used = 0
      cumulative_tokens = 0
      previous_model = self.model_used

      SapAgent::Config::ADAPTIVE_ITERATION_CAP.times do |idx|
        iteration_number = idx + 1
        current_model = self.model_used

        output = generate_iteration_output(context.join("\n"), iteration_number, current_model)
        iterations << { iteration: iteration_number, output: output, model_used: current_model }

        token_count = estimate_tokens(context.join("\n") + output.to_s)
        cumulative_tokens += token_count

        log_iterate_event("adaptive.iteration", iteration: iteration_number, token_count: token_count, cumulative_tokens: cumulative_tokens, model_used: current_model)

        if cumulative_tokens > SapAgent::Config::ADAPTIVE_TOKEN_BUDGET
          log_iterate_event("adaptive.abort", reason: "token_budget_exceeded", token_count: cumulative_tokens, iteration: iteration_number)
          return { status: "aborted", reason: "token_budget_exceeded", token_count: cumulative_tokens, iterations: iterations, partial_output: output }
        end

        score = score_output(output, context.join("\n"))
        normalized_score = normalize_score(score, current_model, previous_model)

        log_iterate_event("adaptive.scored", iteration: iteration_number, score: normalized_score, token_count: cumulative_tokens, model_used: current_model)

        context << "Iteration #{iteration_number} output: #{output}"

        if normalized_score >= SapAgent::Config::SCORE_STOP_THRESHOLD
          elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          log_iterate_event("adaptive.complete", iteration: iteration_number, score: normalized_score, elapsed_ms: elapsed, model_used: current_model)
          return { status: "completed", iterations: iterations, final_output: output, score: normalized_score, model_used: current_model }
        end

        escalation_triggered = normalized_score < SapAgent::Config::SCORE_ESCALATE_THRESHOLD || cumulative_tokens > SapAgent::Config::ADAPTIVE_TOKEN_BUDGET

        if escalation_triggered && escalation_used < SapAgent::Config::ADAPTIVE_MAX_ESCALATIONS
          next_model = next_escalation_model(current_model)
          if next_model
            escalation_used += 1
            log_iterate_event("adaptive.escalate", iteration: iteration_number, from: current_model, to: next_model, escalation_used: escalation_used)
            previous_model = current_model
            self.model_used = next_model
            retry_count = 0
            next
          end
        end

        if retry_count < SapAgent::Config::ADAPTIVE_RETRY_LIMIT
          backoff_ms = SapAgent::Config::BACKOFF_MS[retry_count] || SapAgent::Config::BACKOFF_MS.last
          SapAgent::TimeoutWrapper.with_timeout((backoff_ms / 1000.0) + 0.1) { sleep(backoff_ms / 1000.0) }
          retry_count += 1
          previous_model = current_model
          next
        end
      end

      log_iterate_event("adaptive.abort", reason: "iteration_cap", iteration: SapAgent::Config::ADAPTIVE_ITERATION_CAP)
      { status: "aborted", reason: "iteration_cap", iterations: iterations, final_output: iterations.last&.dig(:output), model_used: self.model_used }
    rescue StandardError => e
      log_iterate_event("adaptive.error", error: e.message)
      { status: "error", reason: e.message, iterations: iterations }
    end

    def conductor(task:, branch: nil, correlation_id: SecureRandom.uuid, idempotency_uuid: SecureRandom.uuid, refiner_iterations: 3, max_jobs: 5)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      self.task_id = task
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT

      requested_jobs = 2 + refiner_iterations # outliner + reviewer + refiners
      if requested_jobs > max_jobs
        log_conductor_event("conductor.aborted", reason: "max_jobs_exceeded", requested_jobs: requested_jobs, max_jobs: max_jobs, idempotency_uuid: idempotency_uuid)
        return { status: "aborted", reason: "max_jobs_exceeded", requested_jobs: requested_jobs, max_jobs: max_jobs }
      end

      state = {
        task: task,
        idempotency_uuid: idempotency_uuid,
        correlation_id: correlation_id,
        escalation_used: false,
        iterations: [],
        steps: []
      }

      failure_streak = 0
      queue_job_id = -> { SecureRandom.uuid }

      outliner_result = run_sub_agent(:outliner, state, queue_job_id.call, iteration: 1)
      failure_streak = update_failure_streak(outliner_result, failure_streak)
      state = outliner_result[:state]
      return circuit_breaker_fallback(state) if circuit_breaker_tripped?(failure_streak)

      refiner_iterations.times do |idx|
        sub_result = run_sub_agent(:refiner, state, queue_job_id.call, iteration: idx + 1)
        failure_streak = update_failure_streak(sub_result, failure_streak)
        state = sub_result[:state]
        return circuit_breaker_fallback(state) if circuit_breaker_tripped?(failure_streak)
      end

      reviewer_result = run_sub_agent(:reviewer, state, queue_job_id.call, iteration: refiner_iterations + 1)
      failure_streak = update_failure_streak(reviewer_result, failure_streak)
      state = reviewer_result[:state]

      if circuit_breaker_tripped?(failure_streak)
        return circuit_breaker_fallback(state)
      end

      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_conductor_event("conductor.complete", idempotency_uuid: idempotency_uuid, elapsed_ms: elapsed, queue_job_id: reviewer_result[:queue_job_id])

      { status: "completed", state: state, elapsed_ms: elapsed }
    rescue StandardError => e
      log_conductor_event("conductor.error", reason: e.message, idempotency_uuid: idempotency_uuid)
      { status: "error", reason: e.message }
    end
    def queue_handshake(artifact:, task_summary:, task_id:, branch: "main", correlation_id: SecureRandom.uuid, idempotency_uuid: SecureRandom.uuid, artifact_path: nil)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      self.task_id = task_id
      self.branch = branch
      self.correlation_id = correlation_id
      self.model_used = SapAgent::Config::MODEL_DEFAULT
      duplicate = git_log_for_uuid(idempotency_uuid)
      if duplicate
        log_queue_event("queue_handshake.duplicate", idempotency_uuid: idempotency_uuid, commit_hash: duplicate)
        return { status: "skipped", reason: "duplicate", commit_hash: duplicate, idempotency_uuid: idempotency_uuid }
      end
      stashed = false
      stash_applied = false
      unless git_status_clean?
        3.times do |attempt|
          stashed = stash_working_changes(idempotency_uuid)
          log_queue_event("queue_handshake.stash", attempt: attempt + 1, idempotency_uuid: idempotency_uuid, stashed: stashed)
          break if stashed && git_status_clean?
        end
        unless stashed && git_status_clean?
          log_queue_event("queue_handshake.error", reason: "dirty_workspace", idempotency_uuid: idempotency_uuid)
          return { status: "error", reason: "dirty_workspace" }
        end
      end
      target_path = artifact_path || Rails.root.join("knowledge_base/epics/AGENT-02C/queue_artifacts", "#{task_id}.json")
      write_artifact(target_path, artifact)
      commit_message = "AGENT-02C-#{task_id}: #{task_summary} by SAP [Links to PRD: AGENT-02C-0040]"
      unless git_add(target_path)
        log_queue_event("queue_handshake.error", reason: "git_add_failed", idempotency_uuid: idempotency_uuid)
        return { status: "error", reason: "git_add_failed" }
      end
      commit_hash = git_commit(commit_message, idempotency_uuid)
      unless commit_hash
        log_queue_event("queue_handshake.error", reason: "git_commit_failed", idempotency_uuid: idempotency_uuid)
        return { status: "error", reason: "git_commit_failed" }
      end
      tests_ok = tests_green?
      unless tests_ok
        log_queue_event("queue_handshake.push_skipped", reason: "tests_failed", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
        stash_applied = pop_stash_with_retry if stashed
        return { status: "error", reason: "tests_failed", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid }
      end
      if ENV["DRY_RUN"].present?
        log_queue_event("queue_handshake.dry_run", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
      else
        push_ok = git_push(branch)
        unless push_ok
          log_queue_event("queue_handshake.error", reason: "push_failed", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
          stash_applied = pop_stash_with_retry if stashed
          return { status: "error", reason: "push_failed", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid }
        end
      end
      if stashed
        stash_applied = pop_stash_with_retry
        unless stash_applied
          log_queue_event("queue_handshake.error", reason: "stash_apply_conflict", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash)
          return { status: "error", reason: "stash_apply_conflict", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid }
        end
      end
      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_queue_event("queue_handshake.complete", idempotency_uuid: idempotency_uuid, commit_hash: commit_hash, elapsed_ms: elapsed)
      { status: "committed", commit_hash: commit_hash, idempotency_uuid: idempotency_uuid, elapsed_ms: elapsed }
    rescue StandardError => e
      log_queue_event("queue_handshake.error", reason: e.message, idempotency_uuid: idempotency_uuid)
      { status: "error", reason: e.message }
    ensure
      stash_applied ||= false
      pop_stash_with_retry if stashed && !stash_applied
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

    def prune_context(context:, correlation_id: SecureRandom.uuid, min_keep: SapAgent::Config::PRUNE_MIN_KEEP_TOKENS, target_tokens: SapAgent::Config::PRUNE_TARGET_TOKENS)
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      self.correlation_id = correlation_id

      tokens = estimate_tokens(context.to_s)
      if tokens <= target_tokens
        log_conductor_event("prune.skipped", reason: "under_target", token_count: tokens, correlation_id: correlation_id)
        return { status: "skipped", context: context, token_count: tokens }
      end

      pruned = prune_by_heuristic(context)
      pruned_tokens = estimate_tokens(pruned)

      if pruned_tokens < min_keep
        log_conductor_event("prune.warning", reason: "min_keep_floor", token_count: pruned_tokens, min_keep: min_keep, correlation_id: correlation_id)
        return { status: "warning", context: context, token_count: tokens, warning: "min_keep_floor" }
      end

      elapsed = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
      log_conductor_event("prune.complete", pruned_tokens: pruned_tokens, original_tokens: tokens, correlation_id: correlation_id, elapsed_ms: elapsed)

      { status: "pruned", context: minify_context(pruned), token_count: pruned_tokens, original_tokens: tokens, elapsed_ms: elapsed }
    rescue StandardError => e
      log_conductor_event("prune.error", reason: e.message, correlation_id: correlation_id)
      { status: "error", context: context, token_count: tokens }
    end

    def poll_task_state(task_id)
      state_path = Rails.root.join("tmp", "sap_iter_state_#{task_id}.json")
      return { status: "pending", message: "No state found" } unless File.exist?(state_path)

      JSON.parse(File.read(state_path)).with_indifferent_access
    rescue StandardError => e
      log_iterate_event("iterate.error", error: e.message, task_id: task_id)
      { status: "error", message: e.message }
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

    def git_log_for_uuid(idempotency_uuid)
      stdout, status = Open3.capture3("git", "log", "--pretty=format:%H", "--grep", idempotency_uuid.to_s)
      return nil unless status.success?

      stdout.to_s.split("\n").reject(&:empty?).first
    end

    def git_status_clean?
      stdout, status = Open3.capture3("git", "status", "--porcelain")
      status.success? && stdout.to_s.strip.empty?
    end

    def stash_working_changes(idempotency_uuid)
      _, status = Open3.capture3("git", "stash", "push", "-u", "-m", "sap-queue-handshake-#{idempotency_uuid}")
      status.success?
    end

    def pop_stash_with_retry
      3.times do
        stdout, status = Open3.capture3("git", "stash", "pop")
        return true if status.success?

        return false if stdout.to_s.include?("Merge conflict")
      end

      false
    end

    def write_artifact(path, artifact)
      FileUtils.mkdir_p(File.dirname(path))
      content = artifact.is_a?(String) ? artifact : artifact.to_json
      File.write(path, content)
      path
    end

    def git_add(path)
      _, status = Open3.capture3("git", "add", path.to_s)
      status.success?
    end

    def git_commit(message, idempotency_uuid)
      env = {
        "GIT_AUTHOR_NAME" => "SAP Agent",
        "GIT_AUTHOR_EMAIL" => "sap@nextgen-plaid.com",
        "GIT_COMMITTER_NAME" => "SAP Agent",
        "GIT_COMMITTER_EMAIL" => "sap@nextgen-plaid.com"
      }

      commit_body = "Idempotency-UUID: #{idempotency_uuid}"
      _, status = Open3.capture3(env, "git", "commit", "-m", message, "-m", commit_body)
      return nil unless status.success?

      stdout, rev_status = Open3.capture3("git", "rev-parse", "HEAD")
      return nil unless rev_status.success?

      stdout.to_s.strip
    end

    def tests_green?
      system("bundle", "exec", "rails", "test")
    end

    def git_push(branch)
      remote = ENV.fetch("GIT_REMOTE", "origin")
      _, status = Open3.capture3("git", "push", remote.to_s, branch.to_s)
      status.success?
    end

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

    def log_queue_event(event, data = {})
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

    def log_conductor_event(event, data = {})
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

    def prune_by_heuristic(context)
      items = context.is_a?(Array) ? context : context.to_s.split("\n").reject(&:blank?)

      scored = items.map do |chunk|
        relevance = ollama_relevance(chunk)
        age_score = age_weight(chunk)
        weight = (0.7 * relevance) + (0.3 * age_score)
        { chunk: chunk, weight: weight }
      end

      sorted = scored.sort_by { |c| -c[:weight] }
      kept = []
      sorted.each do |entry|
        kept << entry[:chunk]
        break if estimate_tokens(kept.join("\n\n")) >= SapAgent::Config::PRUNE_MIN_KEEP_TOKENS
      end

      kept.join("\n\n")
    end

    def ollama_relevance(chunk)
      # Stub relevance to 1.0; in production, call model. Tests will stub.
      1.0
    end

    def age_weight(chunk)
      # Parse timestamps; if older than 30 days, downweight to 0.
      match = chunk.to_s.match(/(\d{4}-\d{2}-\d{2})/)
      return 1.0 unless match

      begin
        date = Date.parse(match[1])
        (Date.today - date) > 30 ? 0.0 : 1.0
      rescue ArgumentError
        1.0
      end
    end

    def minify_context(text)
      text.to_s.split("\n").map do |line|
        if line.include?("|")
          parts = line.split("|").map(&:strip)
          parts.take(2).join(" | ")
        else
          line
        end
      end.join("\n")
    end

    def normalize_score(score, current_model, previous_model)
      return score if current_model == previous_model

      adjusted = score * 0.95
      [ [ adjusted, 0 ].max, 100 ].min
    end

    def next_escalation_model(current_model)
      order = SapAgent::Config::ADAPTIVE_ESCALATION_ORDER
      index = order.index(current_model)
      return order.first unless index

      order[index + 1] || order.first
    end

    def logger
      @logger ||= Logger.new(Rails.root.join("agent_logs/sap.log"))
    end

    def score_output(output, context)
      # Default heuristic score; tests will stub this method for deterministic behavior.
      length_score = [ (output.to_s.length + context.to_s.length) / 10, 100 ].min
      [ length_score, SapAgent::Config::SCORE_STOP_THRESHOLD ].min
    end

    def run_sub_agent(sub_agent, state, queue_job_id, iteration: nil)
      payload = state.merge(queue_job_id: queue_job_id, sub_agent: sub_agent, iteration: iteration)
      log_conductor_event("conductor.route", payload)

      result = nil
      SapAgent::TimeoutWrapper.with_timeout(1) do
        result =
          case sub_agent
          when :outliner then sub_agent_outliner(state)
          when :refiner then sub_agent_refiner(state, iteration)
          when :reviewer then sub_agent_reviewer(state)
          else
            { status: "error", state: state, reason: "unknown_sub_agent" }
          end
      end

      result ||= { status: "error", state: state, reason: "no_result" }
      new_state = safe_state_roundtrip(result[:state] || state)
      log_conductor_event("conductor.state_saved", sub_agent: sub_agent, queue_job_id: queue_job_id, iteration: iteration)

      result.merge(state: new_state, queue_job_id: queue_job_id)
    rescue StandardError => e
      log_conductor_event("conductor.error", sub_agent: sub_agent, queue_job_id: queue_job_id, reason: e.message)
      { status: "error", reason: e.message, state: state, queue_job_id: queue_job_id }
    end

    def sub_agent_outliner(state)
      steps = [ "Gather requirements", "Design", "Implement", "Test" ]
      new_state = state.dup
      new_state[:steps] = (state[:steps] || []) + [ "outliner" ]
      new_state[:outline] = steps
      { status: "ok", state: new_state }
    end

    def sub_agent_refiner(state, iteration)
      new_state = state.dup
      refinements = new_state[:refinements] || []
      refinements << "refinement-#{iteration}"
      new_state[:refinements] = refinements
      new_state[:steps] = (state[:steps] || []) + [ "refiner-#{iteration}" ]
      new_state[:iterations] = (state[:iterations] || []) + [ { iteration: iteration, output: "refined step #{iteration}" } ]
      { status: "ok", state: new_state }
    end

    def sub_agent_reviewer(state)
      new_state = state.dup
      new_state[:steps] = (state[:steps] || []) + [ "reviewer" ]
      new_state[:score] = 85
      { status: "ok", state: new_state }
    end

    def safe_state_roundtrip(state)
      parsed = JSON.parse(state.to_json)
      parsed.is_a?(Hash) ? parsed.with_indifferent_access : state
    rescue JSON::ParserError
      log_conductor_event("conductor.error", reason: "state_validation_failed")
      state
    end

    def update_failure_streak(result, current_streak)
      return 0 if result[:status] == "ok"

      current_streak + 1
    end

    def circuit_breaker_tripped?(failure_streak)
      failure_streak >= 3
    end

    def circuit_breaker_fallback(state)
      log_conductor_event("conductor.circuit_breaker", reason: "failure_streak", state: state)
      { status: "fallback", reason: "circuit_breaker", state: state }
    end

    def generate_iteration_output(context, iteration_number, model)
      prompt = build_iteration_prompt(context, iteration_number)
      response = AiFinancialAdvisor.ask(prompt, model: model, request_id: correlation_id)
      response || "No response from #{model}"
    end

    def build_iteration_prompt(context, iteration_number)
      <<~PROMPT
        You are the SAP (Senior Architect and Product Manager) Agent.

        Iteration: #{iteration_number}

        Context:
        #{context}

        Please provide a detailed, actionable response to continue this task.
        Focus on clarity, completeness, and practical implementation details.
      PROMPT
    end
  end
end
