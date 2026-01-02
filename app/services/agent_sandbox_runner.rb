# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"
require "time"

class AgentSandboxRunner
  def self.run(cmd:, argv: nil, cwd:, correlation_id:, tool_name:)
    payload = {
      cmd: cmd,
      argv: argv,
      cwd: cwd,
      correlation_id: correlation_id,
      tool_name: tool_name
    }

    script = Rails.root.join("script", "agent_sandbox_runner")
    stdout, stderr, status = Open3.capture3({ "AGENT_SANDBOX_PAYLOAD" => JSON.generate(payload) }, script.to_s)

    {
      status: status.exitstatus,
      stdout: stdout,
      stderr: stderr
    }
  end

  def self.ensure_worktree!(correlation_id:, branch:)
    base = Rails.root.join("tmp", "agent_sandbox", correlation_id)
    repo_dir = base.join("repo")
    FileUtils.mkdir_p(base)

    return repo_dir.to_s if Dir.exist?(repo_dir)

    # Create the branch if missing, then create a worktree inside tmp.
    # Execute via the out-of-process sandbox runner to keep tool execution out-of-process.
    root = Rails.root.to_s

    rev = run(
      cmd: "git rev-parse --verify #{branch}",
      argv: [ "git", "rev-parse", "--verify", branch ],
      cwd: root,
      correlation_id: correlation_id,
      tool_name: "AgentSandboxRunner"
    )

    if rev[:status] != 0
      created = run(
        cmd: "git checkout -b #{branch}",
        argv: [ "git", "checkout", "-b", branch ],
        cwd: root,
        correlation_id: correlation_id,
        tool_name: "AgentSandboxRunner"
      )
      raise "failed to create branch: #{created[:stderr]}" unless created[:status] == 0

      restored = run(
        cmd: "git checkout -",
        argv: %w[git checkout -],
        cwd: root,
        correlation_id: correlation_id,
        tool_name: "AgentSandboxRunner"
      )
      raise "failed to restore branch: #{restored[:stderr]}" unless restored[:status] == 0
    end

    added = run(
      cmd: "git worktree add #{repo_dir} #{branch}",
      argv: [ "git", "worktree", "add", repo_dir.to_s, branch ],
      cwd: root,
      correlation_id: correlation_id,
      tool_name: "AgentSandboxRunner"
    )
    raise "failed to create worktree: #{added[:stderr]}" unless added[:status] == 0

    # Some tests/services expect log dirs under Rails.root. In a worktree, Rails.root is the sandbox repo.
    # Ensure required log directories exist so sandbox test runs behave like the main worktree.
    FileUtils.mkdir_p(repo_dir.join("agent_logs"))

    repo_dir.to_s
  end
end
