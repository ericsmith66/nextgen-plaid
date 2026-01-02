class SapAgentJob < ApplicationJob
  queue_as :default

  UPDATE_INTERVAL_SECONDS = 0.5
  UPDATE_INTERVAL_CHARS = 500

  def perform(sap_run_id, assistant_message_id, prompt)
    sap_run = SapRun.find(sap_run_id)
    assistant_message = sap_run.sap_messages.find(assistant_message_id)

    model = SapAgentService.default_model
    Rails.logger.info("[SapAgentJob] sap_run_id=#{sap_run_id} assistant_message_id=#{assistant_message_id} model=#{model}")

    accumulated = +""
    last_write_at = Time.current
    last_write_len = 0

    SapAgentService.stream(prompt, model: model, request_id: sap_run.correlation_id) do |chunk|
      accumulated << chunk.to_s

      now = Time.current
      should_write = (accumulated.length - last_write_len) >= UPDATE_INTERVAL_CHARS ||
        (now - last_write_at) >= UPDATE_INTERVAL_SECONDS

      next unless should_write

      assistant_message.update!(content: accumulated)
      last_write_at = now
      last_write_len = accumulated.length
    end

    assistant_message.update!(content: accumulated)
  rescue StandardError => e
    error_id = SecureRandom.uuid
    Rails.logger.error("[SapAgentJob] error_id=#{error_id} #{e.class}: #{e.message}")

    begin
      SapMessage.find_by(id: assistant_message_id)&.update!(content: "Error: #{e.message} (ID: #{error_id})")
    rescue StandardError
      # Best-effort error display.
    end
  end
end
