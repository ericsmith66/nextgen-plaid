require "test_helper"

class CodeAnalysisToolTest < ActiveSupport::TestCase
  def build_tool_context(correlation_id: "cid-1", turn_count: 0, retry_count: 0, state: {})
    run_context = Agents::RunContext.new({ correlation_id: correlation_id, turn_count: turn_count, state: state })
    Agents::ToolContext.new(run_context: run_context, retry_count: retry_count)
  end

  test "dry run returns would_run" do
    tool = CodeAnalysisTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ENV.stub(:fetch, ->(k, default = nil) { k == "AI_TOOLS_EXECUTE" ? "false" : default }) do
      result = JSON.parse(tool.perform(ctx, file: "app/models/user.rb"))
      assert_equal "dry_run", result["action"]
      assert_includes result["would_run"], "rubocop"
    end
  end

  test "rejects path traversal" do
    tool = CodeAnalysisTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, file: "../secrets.yml")
    end
  end

  test "executes via AgentSandboxRunner" do
    tool = CodeAnalysisTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ENV.stub(:fetch, ->(k, default = nil) { k == "AI_TOOLS_EXECUTE" ? "true" : default }) do
      AgentSandboxRunner.stub(:run, { status: 1, stdout: "", stderr: "C: Layout/LineLength" }) do
        result = JSON.parse(tool.perform(ctx, file: "app/models/user.rb"))
        assert_equal "executed", result["action"]
        assert_equal 1, result["status"]
        assert_includes result["stderr"], "Layout"
      end
    end
  end
end
