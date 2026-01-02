# frozen_string_literal: true

require "test_helper"

class AiWorkflowServiceBroadcastTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActiveJob::TestHelper

  def test_artifact_writer_broadcasts_events
    correlation_id = "cid-broadcast"
    writer = AiWorkflowService::ArtifactWriter.new(correlation_id)

    # In tests, Turbo stream broadcasts are tracked by the signed stream name passed
    # to `broadcast_*_to`, not the internal `Turbo::StreamsChannel.broadcasting_for`.
    stream = "ai_workflow_#{correlation_id}"

    perform_enqueued_jobs do
      assert_broadcasts(stream, 1) do
        writer.record_event(type: "routing_decision", model_id: "ollama")
      end
    end
  end
end
