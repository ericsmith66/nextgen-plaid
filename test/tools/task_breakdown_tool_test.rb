# frozen_string_literal: true

require "test_helper"

class TaskBreakdownToolTest < ActiveSupport::TestCase
  def test_writes_micro_tasks_to_context_and_returns_json
    run_context = Agents::RunContext.new({ correlation_id: "cid" })
    tool_context = Agents::ToolContext.new(run_context: run_context, retry_count: 0)

    prd = <<~MD
      # Title
      ## Overview
      ## Requirements
      ## Acceptance Criteria
      ## Test Cases
    MD

    result = TaskBreakdownTool.new.perform(tool_context, prd_text: prd)
    tasks = JSON.parse(result)

    assert tasks.is_a?(Array)
    assert tasks.length.between?(5, 10)

    tasks.each do |t|
      assert t["id"].present?
      assert t["title"].present?
      assert_includes %w[low med high], t["risk"]
      assert t["estimate"].present?
      assert t["files"].is_a?(Array)
      assert t["commands"].is_a?(Array)
    end

    assert_equal tasks, tool_context.context[:micro_tasks]
  end
end
