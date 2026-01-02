require "test_helper"

class GitToolTest < ActiveSupport::TestCase
  def build_tool_context(correlation_id: "cid-1", turn_count: 0, retry_count: 0, state: {})
    run_context = Agents::RunContext.new({ correlation_id: correlation_id, turn_count: turn_count, state: state })
    Agents::ToolContext.new(run_context: run_context, retry_count: retry_count)
  end

  test "init_sandbox sets sandbox_repo in shared state" do
    tool = GitTool.new
    ctx = build_tool_context(state: {})

    AgentSandboxRunner.stub(:ensure_worktree!, "/tmp/sandbox/repo") do
      result = JSON.parse(tool.perform(ctx, action: "init_sandbox", args: { branch: "feature/test-branch" }))
      assert_equal "ok", result["action"]
      assert_equal "/tmp/sandbox/repo", result["sandbox_repo"]
      assert_equal "/tmp/sandbox/repo", ctx.state[:sandbox_repo]
    end
  end

  test "non-init actions are dry-run by default" do
    tool = GitTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    result = JSON.parse(tool.perform(ctx, action: "status", args: {}))
    assert_equal "dry_run", result["action"]
    assert_equal "status", result["requested"]
  end

  test "blocks commit when tests not run (execute enabled)" do
    tool = GitTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ClimateControl.modify AI_TOOLS_EXECUTE: "true" do
      result = JSON.parse(tool.perform(ctx, action: "commit", args: { message: "msg" }))
      assert_equal "blocked", result["action"]
      assert_equal "tests_not_run", result["reason"]
    end
  end

  test "blocks commit when tests are red (execute enabled)" do
    tool = GitTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s, last_test_exitstatus: 1 })

    ClimateControl.modify AI_TOOLS_EXECUTE: "true" do
      result = JSON.parse(tool.perform(ctx, action: "commit", args: { message: "msg" }))
      assert_equal "blocked", result["action"]
      assert_equal "tests_not_green", result["reason"]
      assert_equal 1, result["exitstatus"]
    end
  end

  test "allows commit when tests are green (execute enabled)" do
    tool = GitTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s, last_test_exitstatus: 0 })

    AgentSandboxRunner.stub(:run, { status: 0, stdout: "committed", stderr: "" }) do
      ClimateControl.modify AI_TOOLS_EXECUTE: "true" do
        result = JSON.parse(tool.perform(ctx, action: "commit", args: { message: "msg" }))
        assert_equal "executed", result["action"]
        assert_includes result["cmd"], "git commit"
      end
    end
  end

  test "enforces max tool calls per turn" do
    tool = GitTool.new
    ctx = build_tool_context(state: {})

    AgentSandboxRunner.stub(:ensure_worktree!, "/tmp/sandbox/repo") do
      10.times do
        JSON.parse(tool.perform(ctx, action: "init_sandbox", args: { branch: "feature/test-branch" }))
      end

      assert_raises(AiWorkflowService::GuardrailError) do
        tool.perform(ctx, action: "init_sandbox", args: { branch: "feature/test-branch" })
      end
    end
  end

  test "enforces max retries" do
    tool = GitTool.new
    ctx = build_tool_context(state: {}, retry_count: 3)

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, action: "init_sandbox", args: { branch: "feature/test-branch" })
    end
  end
end
