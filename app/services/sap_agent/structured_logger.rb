require "json"

module SapAgent
  module StructuredLogger
    LOG_PATH = Rails.root.join("agent_logs/sap.log")

    def log_event(event, data = {})
      payload = base_payload.merge(data).merge(event: event)
      logger.info(payload.to_json)
    end

    def base_payload
      {
        timestamp: Time.now.utc.iso8601,
        task_id: current_task_id,
        branch: current_branch,
        uuid: current_uuid,
        correlation_id: current_correlation_id,
        model_used: current_model,
        elapsed_ms: nil,
        score: nil
      }.compact
    end

    def logger
      @logger ||= Logger.new(LOG_PATH)
    end

    def current_task_id
      @task_id
    end

    def current_branch
      @branch
    end

    def current_uuid
      @uuid ||= SecureRandom.uuid
    end

    def current_correlation_id
      @correlation_id ||= SecureRandom.uuid
    end

    def current_model
      @model_used
    end

    module_function :log_event, :base_payload, :logger, :current_task_id, :current_branch, :current_uuid, :current_correlation_id, :current_model
  end
end
