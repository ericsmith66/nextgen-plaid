# frozen_string_literal: true

require "json"

# PRD 0030: MCP-like read-only tool
class VcTool < Agents::Tool
  description "Read-only git operations in the sandbox repo (status/log/diff). Dry-run by default."

  param :action, type: "string", desc: "One of: status, log, diff"
  param :args, type: "object", desc: "Action-specific arguments"

  MAX_CALLS_PER_TURN = 5
  MAX_RETRIES = 2
  DEFAULT_TIMEOUT_SECONDS = 30

  def perform(tool_context, action:, args: {})
    enforce_tool_guardrails!(tool_context)

    sandbox_repo = tool_context.state[:sandbox_repo]
    raise AiWorkflowService::GuardrailError, "sandbox_repo must be set" if sandbox_repo.blank?

    action = action.to_s
    argv, cmd = build_command(action, args)

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
        errors: res[:status].to_i == 0 ? [] : [ res[:stderr].to_s.presence || "git failed" ]
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

  def build_command(action, args)
    case action
    when "status"
      argv = %w[git status --porcelain]
      [ argv, argv.join(" ") ]
    when "log"
      limit = Integer(args.fetch("limit", 20))
      limit = 1 if limit < 1
      limit = 100 if limit > 100
      argv = [ "git", "log", "--oneline", "-n", limit.to_s ]
      [ argv, argv.join(" ") ]
    when "diff"
      # requirement: diff against main
      base = args.fetch("base", "main").to_s
      raise AiWorkflowService::GuardrailError, "base must be 'main'" unless base == "main"

      argv = %w[git diff main]
      [ argv, argv.join(" ") ]
    else
      raise AiWorkflowService::GuardrailError, "invalid action: #{action}"
    end
  end
end
