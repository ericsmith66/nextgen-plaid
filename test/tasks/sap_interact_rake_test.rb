require "test_helper"
require "rake"
require "ostruct"

class SapInteractRakeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    Rake::Task["sap:interact"].reenable
    ENV["INTERACT_TIMEOUT_SECONDS"] = "1"
    ENV["INTERACT_POLL_INTERVAL"] = "0"
    ENV["USER_EMAIL"] = "ericsmith66@me.com"
  end

  test "denies non-owner access" do
    ENV["USER_EMAIL"] = "not-owner@example.com"
    user = User.create!(email: ENV["USER_EMAIL"], password: "password123")

    fake_auth = Struct.new(:owner?, :admin?).new(false, false)
    SapAgent::AuthService.stub(:new, ->(_user) { fake_auth }) do
      out, _ = capture_io do
        Rake::Task["sap:interact"].invoke("task-123")
      end

      assert_includes out, "Access denied"
    end
  ensure
    user&.destroy
  end

  test "completes and writes temp file when not on mac" do
    user = User.create!(email: ENV["USER_EMAIL"], password: "password123")

    SapAgent.stub(:poll_task_state, ->(_task_id) { { status: "completed", output: "done" } }) do
      SapAgent::InteractHelper.stub(:mac_os?, false) do
        out, _ = capture_io do
          Rake::Task["sap:interact"].invoke("task-456")
        end

        assert_includes out, "Output saved to"
      end
    end
  ensure
    user&.destroy
  end

  test "resumes paused task with feedback" do
    user = User.create!(email: ENV["USER_EMAIL"], password: "password123")
    states = [ { status: "paused", resume_token: "tok-1" } ]

    SapAgent.stub(:poll_task_state, ->(_task_id) { states.shift || { status: "completed", output: "done" } }) do
      SapAgent.stub(:iterate_prompt, ->(task:, resume_token:, human_feedback:, correlation_id: nil) {
        assert_equal "task-789", task
        assert_equal "tok-1", resume_token
        assert_equal "feedback text", human_feedback
        { status: "completed", final_output: "done" }
      }) do
        original_stdin = $stdin
        $stdin = StringIO.new("feedback text\n")

        out, _ = capture_io do
          Rake::Task["sap:interact"].invoke("task-789")
        end

        assert_includes out, "Resumed: completed"
      ensure
        $stdin = original_stdin
      end
    end
  ensure
    user&.destroy
  end
end
