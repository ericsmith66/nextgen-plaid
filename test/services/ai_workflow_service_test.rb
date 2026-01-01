require "test_helper"

class AiWorkflowServiceTest < ActiveSupport::TestCase
  test "runs a 2-agent chain and writes artifacts" do
    fake_sap_result = Agents::RunResult.new(
      output: "SAP draft",
      messages: [ { role: :assistant, content: "SAP draft" } ],
      usage: {},
      context: { correlation_id: "cid-123", turn_count: 1 }
    )
    fake_coordinator_result = Agents::RunResult.new(
      output: "Coordinator assigns ball_with=Coordinator",
      messages: [ { role: :assistant, content: "Coordinator assigns ball_with=Coordinator" } ],
      usage: {},
      context: { correlation_id: "cid-123", turn_count: 2 }
    )

    runners = []
    Agents::Runner.stub(:with_agents, ->(*_agents) {
      # First call: SAP, second call: Coordinator
      seq = runners.length
      runner = Object.new
      def runner.on_run_start(&); self; end
      def runner.on_agent_thinking(&); self; end
      def runner.on_agent_handoff(&); self; end
      def runner.on_agent_complete(&); self; end
      def runner.on_run_complete(&); self; end
      def runner.on_tool_start(&); self; end
      def runner.on_tool_complete(&); self; end
      runner.define_singleton_method(:run) do |_input, context:, **_kwargs|
        # Preserve context chaining semantics
        merged = context.merge(correlation_id: "cid-123")
        if seq == 0
          fake_sap_result.context = merged.merge(turn_count: 1)
          fake_sap_result
        else
          fake_coordinator_result.context = merged.merge(turn_count: 2)
          fake_coordinator_result
        end
      end
      runners << runner
      runner
    }) do
      result = AiWorkflowService.run(prompt: "Generate PRD", correlation_id: "cid-123")

      assert_equal "Coordinator", result.context[:ball_with]
      assert_equal "SAP draft", result.context[:sap_output]
      assert_includes result.output, "Coordinator"

      run_dir = Rails.root.join("agent_logs", "ai_workflow", "cid-123")
      assert File.exist?(run_dir.join("run.json")), "expected run.json to exist"
      assert File.exist?(run_dir.join("events.ndjson")), "expected events.ndjson to exist"
    end
  end

  test "guardrail rejects empty prompt" do
    assert_raises(AiWorkflowService::GuardrailError) do
      AiWorkflowService.run(prompt: "   ")
    end
  end
end
