# frozen_string_literal: true

require "test_helper"

class AiWorkflowServicePlannerTest < ActiveSupport::TestCase
  FakeResult = Struct.new(:output, :context)

  def test_run_once_wires_planner_and_populates_micro_tasks
    context = AiWorkflowService.build_initial_context("cid-50e")
    recorded_events = []
    artifacts = Class.new do
      def initialize(recorded_events)
        @recorded_events = recorded_events
      end

      def attach_callbacks!(_runner); end

      def record_event(payload)
        @recorded_events << payload
      end
    end.new(recorded_events)

    captured_agents = nil

    fake_runner = Class.new do
      def initialize(context)
        @context = context
      end

      def run(input, context:, max_turns: nil, headers: nil)
        # Simulate what the Planner tool would do.
        tool_context = Agents::ToolContext.new(
          run_context: Agents::RunContext.new(context.merge(correlation_id: context[:correlation_id])),
          retry_count: 0
        )

        TaskBreakdownTool.new.perform(tool_context, prd_text: input)

        FakeResult.new(
          "ok",
          tool_context.context.merge(current_agent: "Planner", turn_count: 1)
        )
      end
    end.new(context)

    Agents::Runner.stub :with_agents, ->(*agents) do
      captured_agents = agents
      fake_runner
    end do
      result = AiWorkflowService.run_once(
        prompt: "# Sample PRD\n## Overview\n## Requirements",
        context: context,
        artifacts: artifacts,
        max_turns: 3,
        model: nil
      )

      assert captured_agents.map(&:name).include?("Planner"), "expected Planner agent"
      assert result.context[:micro_tasks].is_a?(Array)
      assert result.context[:micro_tasks].length.between?(5, 10)

      routing = recorded_events.find { |e| e[:type] == "routing_decision" }
      assert routing, "expected routing_decision event"
      assert routing[:model_id].present?
    end
  end
end
