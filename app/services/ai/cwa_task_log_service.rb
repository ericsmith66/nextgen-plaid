# frozen_string_literal: true

require "json"
require "time"

module Ai
  # PRD 0020: Task Log Template & Persistence
  #
  # File-based v1 persistence for CWA task logs.
  # - raw lifecycle events are already captured in `events.ndjson`
  # - this service maintains a structured 12-section log and persists it to:
  #     `cwa_log.json` and `cwa_log.md`
  #   and provides a snapshot suitable for embedding into `run.json`.
  class CwaTaskLogService
    MAX_BYTES = 100_000

    SECTION_KEYS = {
      correlation_and_summary: "1. Correlation ID/Task Summary",
      input_micro_task: "2. Input Micro-Task",
      plan: "3. Plan",
      execute: "4. Execute",
      test: "5. Test",
      debug: "6. Debug",
      retry: "7. Retry",
      checkpoint: "8. Checkpoint",
      output_artifacts: "9. Output Artifacts",
      failure_analysis: "10. Failure Analysis",
      ball_with: "11. Ball With/Ownership Update",
      final_status: "12. Final Status"
    }.freeze

    def initialize(correlation_id:, artifact_writer:)
      @correlation_id = correlation_id
      @artifact_writer = artifact_writer
      @last_tool_args = nil

      @log = load_existing_log || default_log
    end

    def snapshot
      @log
    end

    def markdown
      render_markdown(@log)
    end

    # --- Runner hooks ---

    def on_run_start(agent_name, input, context_wrapper)
      @log["task_summary"] ||= input.to_s.strip
      @log["sections"]["correlation_and_summary"] = {
        correlation_id: @correlation_id,
        task_summary: @log["task_summary"]
      }

      # Pull micro-tasks from context if present (Planner phase).
      ctx = context_wrapper&.respond_to?(:context) ? context_wrapper.context : nil
      micro_tasks = ctx&.dig(:micro_tasks) || ctx&.dig("micro_tasks")
      if micro_tasks.present?
        @log["sections"]["input_micro_task"] = { micro_tasks: micro_tasks }
      end

      persist!(event: "run_start", agent: agent_name)
    end

    def on_agent_handoff(from_agent, to_agent, reason)
      return unless to_agent.to_s == "CWA"

      @log["started_at"] ||= Time.now.utc.iso8601
      @log["sections"]["ball_with"] = {
        ball_with: "CWA",
        from: from_agent,
        reason: reason
      }

      persist!(event: "handoff_to_cwa", from: from_agent, reason: reason)
    end

    def on_tool_start(tool_name, args)
      @last_tool_args = args
      persist!(event: "tool_start", tool: tool_name, args: args)
    end

    def on_tool_complete(tool_name, result)
      entry = {
        ts: Time.now.utc.iso8601,
        tool: tool_name,
        args: @last_tool_args,
        result: safe_parse_result(result)
      }

      if tool_name.to_s == "SafeShellTool"
        cmd = entry.dig(:args, "cmd") || entry.dig(:args, :cmd)
        if cmd.to_s.match?(/\Abundle\s+exec\s+(rake\s+test|rails\s+test|rubocop|brakeman)/i)
          @log["sections"]["test"]["entries"] << entry
        else
          @log["sections"]["execute"]["entries"] << entry
        end
      else
        @log["sections"]["execute"]["entries"] << entry
      end

      persist!(event: "tool_complete", tool: tool_name)
    end

    def on_agent_complete(agent_name, _result, error, context_wrapper)
      return unless agent_name.to_s == "CWA"

      ctx = context_wrapper&.respond_to?(:context) ? context_wrapper.context : nil
      @log["sections"]["checkpoint"] = {
        ts: Time.now.utc.iso8601,
        context_snapshot: ctx
      }

      if error
        @log["sections"]["failure_analysis"] = {
          error: error.message,
          error_class: error.class.name
        }
        @log["sections"]["final_status"] = { status: "blocked", reason: error.message }
      else
        @log["sections"]["final_status"] = { status: "resolved" }
      end

      @log["completed_at"] ||= Time.now.utc.iso8601

      persist!(event: "cwa_complete", status: @log.dig("sections", "final_status"))
    end

    def on_run_complete(agent_name, _result, context_wrapper)
      # Persist one last time (covers non-CWA terminal runs too).
      ctx = context_wrapper&.respond_to?(:context) ? context_wrapper.context : nil
      ball_with = ctx&.dig(:ball_with) || ctx&.dig("ball_with")
      @log["sections"]["ball_with"] ||= { ball_with: ball_with }

      persist!(event: "run_complete", agent: agent_name)
    end

    private

    def base_dir
      Rails.root.join("agent_logs", "ai_workflow", @correlation_id)
    end

    def log_json_path
      base_dir.join("cwa_log.json")
    end

    def log_md_path
      base_dir.join("cwa_log.md")
    end

    def default_log
      {
        "version" => "0020",
        "correlation_id" => @correlation_id,
        "started_at" => nil,
        "completed_at" => nil,
        "task_summary" => nil,
        "sections" => {
          "correlation_and_summary" => {},
          "input_micro_task" => {},
          "plan" => {},
          "execute" => { "entries" => [] },
          "test" => { "entries" => [] },
          "debug" => {},
          "retry" => {},
          "checkpoint" => {},
          "output_artifacts" => {},
          "failure_analysis" => {},
          "ball_with" => {},
          "final_status" => {}
        }
      }
    end

    def load_existing_log
      return nil unless File.exist?(log_json_path)
      JSON.parse(File.read(log_json_path))
    rescue StandardError
      nil
    end

    def safe_parse_result(result)
      return result if result.is_a?(Hash) || result.is_a?(Array)
      JSON.parse(result)
    rescue StandardError
      result.to_s
    end

    def persist!(event:, **payload)
      FileUtils.mkdir_p(base_dir)

      # Enforce size cap on the markdown rendering by truncating oldest execute/test entries.
      truncate_to_max_bytes!

      File.write(log_json_path, JSON.pretty_generate(@log) + "\n")
      File.write(log_md_path, render_markdown(@log))

      @artifact_writer.record_event(
        {
          type: "cwa_task_log",
          event: event,
          cwa_log_bytes: File.size?(log_md_path) || 0
        }.merge(payload)
      )
    rescue StandardError => e
      # Graceful failure: do not break the workflow if logging fails.
      Rails.logger&.warn("CWA task log persist failed: #{e.class}: #{e.message}")
    end

    def truncate_to_max_bytes!
      md = render_markdown(@log)
      return if md.bytesize <= MAX_BYTES

      execute_entries = @log.dig("sections", "execute", "entries") || []
      test_entries = @log.dig("sections", "test", "entries") || []

      while md.bytesize > MAX_BYTES && (execute_entries.any? || test_entries.any?)
        # Prefer dropping oldest execute entries first.
        if execute_entries.any?
          execute_entries.shift
        else
          test_entries.shift
        end
        md = render_markdown(@log)
      end

      if md.bytesize > MAX_BYTES
        # As a last resort, truncate the task summary.
        @log["task_summary"] = @log["task_summary"].to_s.byteslice(0, 2000)
      end

      @log["truncated"] = true
    end

    def render_markdown(log)
      s = log.fetch("sections")

      lines = []
      lines << "## 1. Correlation ID / Task Summary"
      lines << "**Correlation ID**: #{log["correlation_id"]}"
      lines << "**Task Summary**: #{log["task_summary"].to_s.strip}"
      lines << ""

      lines << "## 2. Input Micro-Task (from context)"
      lines << JSON.pretty_generate(s["input_micro_task"]) unless s["input_micro_task"].blank?
      lines << ""

      lines << "## 3. Plan (steps/tools)"
      lines << JSON.pretty_generate(s["plan"]) unless s["plan"].blank?
      lines << ""

      lines << "## 4. Execute (tool calls/output)"
      Array(s.dig("execute", "entries")).each do |e|
        lines << "- #{e[:ts] || e["ts"]} #{e[:tool] || e["tool"]} #{(e[:args] || e["args"]).to_json}"
      end
      lines << ""

      lines << "## 5. Test (rake/rubocop/brakeman results)"
      Array(s.dig("test", "entries")).each do |e|
        lines << "- #{e[:ts] || e["ts"]} #{e[:tool] || e["tool"]} #{(e[:args] || e["args"]).to_json}"
      end
      lines << ""

      lines << "## 6. Debug (failures/parsings)"
      lines << JSON.pretty_generate(s["debug"]) unless s["debug"].blank?
      lines << ""

      lines << "## 7. Retry (fixes attempted)"
      lines << JSON.pretty_generate(s["retry"]) unless s["retry"].blank?
      lines << ""

      lines << "## 8. Checkpoint (state snapshot)"
      lines << JSON.pretty_generate(s["checkpoint"]) unless s["checkpoint"].blank?
      lines << ""

      lines << "## 9. Output Artifacts (files/commits)"
      lines << JSON.pretty_generate(s["output_artifacts"]) unless s["output_artifacts"].blank?
      lines << ""

      lines << "## 10. Failure Analysis (if escalated)"
      lines << JSON.pretty_generate(s["failure_analysis"]) unless s["failure_analysis"].blank?
      lines << ""

      lines << "## 11. Ball With / Ownership Update"
      lines << JSON.pretty_generate(s["ball_with"]) unless s["ball_with"].blank?
      lines << ""

      lines << "## 12. Final Status (resolved/blocked)"
      lines << JSON.pretty_generate(s["final_status"]) unless s["final_status"].blank?
      lines << ""

      lines.join("\n")
    end
  end
end
