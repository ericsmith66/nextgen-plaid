# frozen_string_literal: true

require "open3"
require "json"
require "fileutils"
require "shellwords"

class SafeShellTool < Agents::Tool
  description "Run an allowlisted shell command inside the per-run sandbox worktree (dry-run by default)."
  param :cmd, type: "string", desc: "Shell command to run (deny-by-default allowlist)"

  MAX_CALLS_PER_TURN = 5
  MAX_RETRIES = 2

  # Deny-by-default: only allow a small, explicit set of common dev commands.
  # NOTE: We intentionally do not allow network tools (curl/wget/ssh) or destructive ops (rm).
  ALLOWLIST = [
    /\Abundle\s+exec\s+rake\s+test(\s+.*)?\z/i,
    /\Abundle\s+exec\s+rails\s+test(\s+.*)?\z/i,
    /\Abundle\s+exec\s+ruby\s+-v\z/i,
    /\Abundle\s+exec\s+rake\s+-T\z/i,
    /\Abundle\s+exec\s+rubocop(\s+.*)?\z/i,
    /\Abundle\s+exec\s+rails\s+g\s+.*\z/i,
    /\Agit\s+status\z/i,
    /\Agit\s+diff(\s+.*)?\z/i,
    /\Als(\s+.*)?\z/i
  ].freeze

  # Quick-deny patterns for obviously unsafe commands even if someone broadens allowlist later.
  DENYLIST = [
    /\brm\b/i,
    /\bshutdown\b/i,
    /\breboot\b/i,
    /\bcurl\b/i,
    /\bwget\b/i,
    /\bssh\b/i,
    /\bscp\b/i,
    /\bgit\s+push\b/i,
    /\bgit\s+fetch\b/i,
    /\bgit\s+pull\b/i,
    /\bgit\s+remote\b/i,
    /\bexport\s+\w+=/i
  ].freeze

  def perform(tool_context, cmd:)
    correlation_id = tool_context.context[:correlation_id] || tool_context.context["correlation_id"]
    raise AiWorkflowService::GuardrailError, "missing correlation_id" if correlation_id.nil? || correlation_id.to_s.empty?

    enforce_tool_guardrails!(tool_context)

    cmd = cmd.to_s.strip
    return format_result(action: "blocked", cmd: cmd, reason: "empty cmd") if cmd.empty?

    if DENYLIST.any? { |rx| rx.match?(cmd) }
      return format_result(action: "blocked", cmd: cmd, reason: "denylist")
    end

    unless ALLOWLIST.any? { |rx| rx.match?(cmd) }
      return format_result(action: "blocked", cmd: cmd, reason: "not_allowlisted")
    end

    sandbox_repo = tool_context.state[:sandbox_repo]
    return format_result(action: "blocked", cmd: cmd, reason: "sandbox_not_initialized") if sandbox_repo.nil? || sandbox_repo.to_s.empty?

    # Never allow tool execution from inside the sandbox runner itself; this can recurse
    # (e.g., running tool tests in the sandbox calling tools again).
    nested_sandbox = ENV.fetch("AGENT_SANDBOX_ACTIVE", "0").to_s == "1"
    execute_enabled = !nested_sandbox && ENV.fetch("AI_TOOLS_EXECUTE", "false").to_s.downcase == "true"
    unless execute_enabled
      return format_result(action: "dry_run", cmd: cmd, cwd: sandbox_repo)
    end

    argv = Shellwords.split(cmd)

    if cmd.match?(/\Abundle\s+exec\s+(rake\s+test|rails\s+test)/i)
      timeout_seconds = Integer(ENV.fetch("AI_TOOLS_TEST_TIMEOUT_SECONDS", "300"))
    else
      timeout_seconds = Integer(ENV.fetch("AI_TOOLS_CMD_TIMEOUT_SECONDS", "30"))
    end

    result = AgentSandboxRunner.run(
      cmd: cmd,
      argv: argv,
      cwd: sandbox_repo,
      correlation_id: correlation_id,
      tool_name: self.class.name,
      timeout_seconds: timeout_seconds
    )

    record_test_status!(tool_context, cmd: cmd, result: result)
    format_result(action: "executed", cmd: cmd, cwd: sandbox_repo, result: result)
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

  def format_result(action:, cmd:, reason: nil, cwd: nil, result: nil)
    payload = {
      action: action,
      cmd: cmd
    }
    payload[:reason] = reason if reason
    payload[:cwd] = cwd if cwd
    payload[:result] = result if result
    JSON.pretty_generate(payload)
  end

  def record_test_status!(tool_context, cmd:, result:)
    # Record the last test command's exit status so GitTool can enforce "commit only when green".
    return unless cmd.match?(/\Abundle\s+exec\s+(rake\s+test|rails\s+test)/i)

    tool_context.state[:last_test_cmd] = cmd
    tool_context.state[:last_test_exitstatus] = result[:status]
  end
end
