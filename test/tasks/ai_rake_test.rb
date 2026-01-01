require "test_helper"
require "rake"

class AiRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["ai:run_request"].reenable
  end

  test "prints correlation_id and ball_with" do
    fake_result = Agents::RunResult.new(
      output: "Coordinator response",
      messages: [ { role: :assistant, content: "Coordinator response" } ],
      usage: {},
      context: { correlation_id: "cid-xyz", ball_with: "Coordinator" }
    )

    AiWorkflowService.stub(:run, fake_result) do

      out, _err = capture_io do
        Rake::Task["ai:run_request"].invoke("Generate PRD")
      end

      assert_includes out, "correlation_id=", "expected correlation_id in output"
      assert_includes out, "ball_with=Coordinator"
    end
  end

  test "guardrail error exits non-zero" do
    err = assert_raises(SystemExit) do
      capture_io { Rake::Task["ai:run_request"].invoke("   ") }
    end
    assert_equal 1, err.status
  end
end
