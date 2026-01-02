require "test_helper"

class SafeShellToolTest < ActiveSupport::TestCase
  def build_tool_context(correlation_id: "cid-1", turn_count: 0, retry_count: 0, state: {})
    run_context = Agents::RunContext.new({ correlation_id: correlation_id, turn_count: turn_count, state: state })
    Agents::ToolContext.new(run_context: run_context, retry_count: retry_count)
  end

  test "blocks non-allowlisted commands" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    result = JSON.parse(tool.perform(ctx, cmd: "echo hi"))
    assert_equal "blocked", result["action"]
    assert_equal "not_allowlisted", result["reason"]
  end

  test "blocks denylisted commands even if otherwise allowlisted" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    result = JSON.parse(tool.perform(ctx, cmd: "rm -rf tmp"))
    assert_equal "blocked", result["action"]
    assert_equal "denylist", result["reason"]
  end

  test "requires sandbox to be initialized" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: {})

    result = JSON.parse(tool.perform(ctx, cmd: "bundle exec rake test"))
    assert_equal "blocked", result["action"]
    assert_equal "sandbox_not_initialized", result["reason"]
  end

  test "is dry-run by default" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    result = JSON.parse(tool.perform(ctx, cmd: "bundle exec rake test"))
    assert_equal "dry_run", result["action"]
    assert_equal Rails.root.to_s, result["cwd"]
  end

  test "records last test exit status when executing" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    AgentSandboxRunner.stub(:run, { status: 0, stdout: "ok", stderr: "" }) do
      ClimateControl.modify AI_TOOLS_EXECUTE: "true" do
        result = JSON.parse(tool.perform(ctx, cmd: "bundle exec rake test"))
        assert_equal "executed", result["action"]
        assert_equal 0, ctx.state[:last_test_exitstatus]
        assert_equal "bundle exec rake test", ctx.state[:last_test_cmd]
      end
    end
  end

  test "enforces max tool calls per turn" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    5.times do
      JSON.parse(tool.perform(ctx, cmd: "bundle exec rake test"))
    end

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, cmd: "bundle exec rake test")
    end
  end

  test "enforces max retries" do
    tool = SafeShellTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s }, retry_count: 3)

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, cmd: "bundle exec rake test")
    end
  end
end
