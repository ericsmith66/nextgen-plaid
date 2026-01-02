require "test_helper"

class VcToolTest < ActiveSupport::TestCase
  def build_tool_context(correlation_id: "cid-1", turn_count: 0, retry_count: 0, state: {})
    run_context = Agents::RunContext.new({ correlation_id: correlation_id, turn_count: turn_count, state: state })
    Agents::ToolContext.new(run_context: run_context, retry_count: retry_count)
  end

  test "dry run returns would_run" do
    tool = VcTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ENV.stub(:fetch, ->(k, default = nil) { k == "AI_TOOLS_EXECUTE" ? "false" : default }) do
      result = JSON.parse(tool.perform(ctx, action: "status", args: {}))
      assert_equal "dry_run", result["action"]
      assert_includes result["would_run"], "git status"
    end
  end

  test "rejects invalid action" do
    tool = VcTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, action: "reset", args: {})
    end
  end

  test "diff enforces base main" do
    tool = VcTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, action: "diff", args: { "base" => "develop" })
    end
  end

  test "executes via AgentSandboxRunner" do
    tool = VcTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ENV.stub(:fetch, ->(k, default = nil) { k == "AI_TOOLS_EXECUTE" ? "true" : default }) do
      AgentSandboxRunner.stub(:run, { status: 0, stdout: " M app/models/user.rb\n", stderr: "" }) do
        result = JSON.parse(tool.perform(ctx, action: "status", args: {}))
        assert_equal "executed", result["action"]
        assert_includes result["stdout"], "app/models/user.rb"
      end
    end
  end
end
