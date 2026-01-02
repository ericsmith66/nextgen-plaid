require "test_helper"

class ProjectSearchToolTest < ActiveSupport::TestCase
  def build_tool_context(correlation_id: "cid-1", turn_count: 0, retry_count: 0, state: {})
    run_context = Agents::RunContext.new({ correlation_id: correlation_id, turn_count: turn_count, state: state })
    Agents::ToolContext.new(run_context: run_context, retry_count: retry_count)
  end

  test "dry run returns would_run" do
    tool = ProjectSearchTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ENV.stub(:fetch, ->(k, default = nil) { k == "AI_TOOLS_EXECUTE" ? "false" : default }) do
      result = JSON.parse(tool.perform(ctx, query: "def perform"))
      assert_equal "dry_run", result["action"]
      assert_includes result["would_run"], "grep"
    end
  end

  test "rejects non-allowlisted paths" do
    tool = ProjectSearchTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    assert_raises(AiWorkflowService::GuardrailError) do
      tool.perform(ctx, query: "def", paths: [ "config" ])
    end
  end

  test "executes via AgentSandboxRunner and parses grep output" do
    tool = ProjectSearchTool.new
    ctx = build_tool_context(state: { sandbox_repo: Rails.root.to_s })

    ENV.stub(:fetch, ->(k, default = nil) { k == "AI_TOOLS_EXECUTE" ? "true" : default }) do
      AgentSandboxRunner.stub(:run, { status: 0, stdout: "app/models/user.rb:12:def name\n", stderr: "" }) do
        result = JSON.parse(tool.perform(ctx, query: "def name", paths: [ "app" ]))
        assert_equal "executed", result["action"]
        assert_equal 1, result["results"].length
        assert_equal "app/models/user.rb", result["results"][0]["file"]
        assert_equal 12, result["results"][0]["line"]
      end
    end
  end
end
