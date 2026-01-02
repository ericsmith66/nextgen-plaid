# frozen_string_literal: true

require "json"

# PRD 0030: MCP-like read-only tool
class CodeAnalysisTool < Agents::Tool
  description "Run read-only static analysis (rubocop output only, no auto-correct). Dry-run by default."

  param :file, type: "string", desc: "Optional file path relative to repo root"

  MAX_CALLS_PER_TURN = 5
  MAX_RETRIES = 2
  DEFAULT_TIMEOUT_SECONDS = 30

  def perform(tool_context, file: nil)
    enforce_tool_guardrails!(tool_context)

    sandbox_repo = tool_context.state[:sandbox_repo]
    raise AiWorkflowService::GuardrailError, "sandbox_repo must be set" if sandbox_repo.blank?

    argv = build_argv(file)
    cmd = argv.join(" ")

    execute_enabled = ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
    unless execute_enabled
      return JSON.generate({ action: "dry_run", would_run: cmd, cwd: sandbox_repo, stdout: "", stderr: "", status: nil, errors: [] })
    end

    timeout_seconds = Integer(ENV.fetch("AI_TOOLS_CMD_TIMEOUT_SECONDS", DEFAULT_TIMEOUT_SECONDS.to_s))
    res = AgentSandboxRunner.run(
      cmd: cmd,
      argv: argv,
      cwd: sandbox_repo,
      correlation_id: tool_context.context[:correlation_id] || tool_context.context["correlation_id"],
      tool_name: self.class.name,
      timeout_seconds: timeout_seconds
    )

    JSON.generate(
      {
        action: "executed",
        cwd: sandbox_repo,
        status: res[:status],
        stdout: res[:stdout].to_s,
        stderr: res[:stderr].to_s,
        errors: res[:status].to_i == 0 ? [] : [ res[:stderr].to_s.presence || "rubocop failed" ]
      }
    )
  end

  private

  def enforce_tool_guardrails!(tool_context)
    turn = (tool_context.context[:turn_count] || tool_context.context["turn_count"] || 0).to_i
    tool_context.context[:tool_calls_by_turn] ||= {}
    tool_context.context[:tool_calls_by_turn][turn] ||= 0
    tool_context.context[:tool_calls_by_turn][turn] += 1

    if tool_context.context[:tool_calls_by_turn][turn] > MAX_CALLS_PER_TURN
      raise AiWorkflowService::GuardrailError, "max tool calls exceeded for turn #{turn}"
    end

    if tool_context.retry_count.to_i > MAX_RETRIES
      raise AiWorkflowService::GuardrailError, "max tool retries exceeded"
    end
  end

  def build_argv(file)
    # no autocorrect, no network, output only.
    if file.present?
      safe = file.to_s
      # Restrict to repo-local file paths.
      if safe.include?("..") || safe.start_with?("/")
        raise AiWorkflowService::GuardrailError, "invalid file path"
      end
      [ "bundle", "exec", "rubocop", "--force-exclusion", safe ]
    else
      %w[bundle exec rubocop --force-exclusion]
    end
  end
end
