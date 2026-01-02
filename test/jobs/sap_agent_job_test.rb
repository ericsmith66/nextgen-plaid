require "test_helper"

class SapAgentJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  include ActionCable::TestHelper

  test "accumulates streamed chunks into a single assistant message" do
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    sap_run = SapRun.create!(
      user: user,
      correlation_id: SecureRandom.uuid,
      status: "running",
      started_at: Time.current
    )

    stream = "sap_run_#{sap_run.id}"

    assistant_message = sap_run.sap_messages.create!(role: :assistant, content: "Thinking...")

    # Creation broadcasts are not part of what we're testing here.
    clear_messages(stream)

    clear_enqueued_jobs

    SapAgentService.stub :stream, ->(_prompt, model: nil, request_id: nil, &blk) {
      assert_equal sap_run.correlation_id, request_id
      [ "Hello ", "world" ].each { |chunk| blk.call(chunk) }
    } do
      SapAgentJob.perform_now(sap_run.id, assistant_message.id, "hi")
    end

    assert_equal "Hello world", assistant_message.reload.content

    # The assistant message update should have resulted in a Turbo Stream broadcast
    # to the per-run stream.
    assert_broadcasts stream, 1
    assert_includes broadcasts(stream).last, "turbo-stream"
    # Broadcast payloads are JSON-escaped in the test adapter, so match loosely.
    assert_includes broadcasts(stream).last, "replace"
  end
end
