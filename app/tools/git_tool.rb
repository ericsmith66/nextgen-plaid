# frozen_string_literal: true

require "json"

class GitTool < Agents::Tool
  description "Perform restricted local git operations in the per-run sandbox worktree (dry-run by default)."

  param :action, type: "string", desc: "One of: init_sandbox, status, diff, add, commit"
  param :args, type: "object", desc: "Action-specific arguments"

  MAX_CALLS_PER_TURN = 10
  MAX_RETRIES = 2

  BRANCH_NAME = /\A[a-z0-9][a-z0-9._\/-]*\z/i

  def perform(tool_context, action:, args: {})
    correlation_id = tool_context.context[:correlation_id] || tool_context.context["correlation_id"]
    raise AiWorkflowService::GuardrailError, "missing correlation_id" if correlation_id.nil? || correlation_id.to_s.empty?

    enforce_tool_guardrails!(tool_context)

    # Never allow tool execution from inside the sandbox runner itself; this can recurse
    # (e.g., running tool tests in the sandbox calling tools again).
    nested_sandbox = ENV.fetch("AGENT_SANDBOX_ACTIVE", "0").to_s == "1"
    execute_enabled = !nested_sandbox && ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
    if !execute_enabled && action.to_s != "init_sandbox"
      return JSON.pretty_generate(action: "dry_run", requested: action, args: args)
    end

    case action.to_s
    when "init_sandbox"
      branch = (args["branch"] || args[:branch] || "feature/prd-50c-cwa-impl").to_s
      unless BRANCH_NAME.match?(branch)
        return JSON.pretty_generate(action: "blocked", requested: action, reason: "invalid_branch", branch: branch)
      end

      sandbox_repo = AgentSandboxRunner.ensure_worktree!(correlation_id: correlation_id, branch: branch)
      tool_context.state[:sandbox_repo] = sandbox_repo
      JSON.pretty_generate(action: "ok", sandbox_repo: sandbox_repo, branch: branch)
    when "status"
      sandbox_repo = require_sandbox!(tool_context)
      run_git(correlation_id, sandbox_repo, "status")
    when "diff"
      sandbox_repo = require_sandbox!(tool_context)
      run_git(correlation_id, sandbox_repo, "diff")
    when "add"
      sandbox_repo = require_sandbox!(tool_context)
      paths = Array(args["paths"] || args[:paths]).map(&:to_s)
      return JSON.pretty_generate(action: "blocked", requested: action, reason: "no_paths") if paths.empty?
      run_git(correlation_id, sandbox_repo, "add", "--", *paths)
    when "commit"
      sandbox_repo = require_sandbox!(tool_context)
      message = (args["message"] || args[:message]).to_s.strip
      return JSON.pretty_generate(action: "blocked", requested: action, reason: "empty_message") if message.empty?

      execute_enabled = ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
      if execute_enabled
        last_status = tool_context.state[:last_test_exitstatus]
        return JSON.pretty_generate(action: "blocked", requested: action, reason: "tests_not_run") if last_status.nil?
        return JSON.pretty_generate(action: "blocked", requested: action, reason: "tests_not_green", exitstatus: last_status) unless last_status.to_i == 0
      end

      run_git(correlation_id, sandbox_repo, "commit", "-m", message)
    else
      JSON.pretty_generate(action: "blocked", requested: action, reason: "unknown_action")
    end
  end

  private

  def require_sandbox!(tool_context)
    sandbox_repo = tool_context.state[:sandbox_repo]
    raise AiWorkflowService::GuardrailError, "sandbox_not_initialized" if sandbox_repo.nil? || sandbox_repo.to_s.empty?

    sandbox_repo
  end

  def run_git(correlation_id, cwd, *argv)
    cmd = ([ "git" ] + argv).join(" ")

    # Enforce local-only policy explicitly.
    if cmd.match?(/\bgit\s+(push|fetch|pull|remote|clone)\b/i)
      return JSON.pretty_generate(action: "blocked", cmd: cmd, reason: "git_remote_op")
    end

    execute_enabled = ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
    unless execute_enabled
      return JSON.pretty_generate(action: "dry_run", cmd: cmd, cwd: cwd)
    end

    result = AgentSandboxRunner.run(
      cmd: cmd,
      argv: [ "git" ] + argv,
      cwd: cwd,
      correlation_id: correlation_id,
      tool_name: self.class.name,
      timeout_seconds: 60
    )
    JSON.pretty_generate(action: "executed", cmd: cmd, cwd: cwd, result: result)
  end

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
end
