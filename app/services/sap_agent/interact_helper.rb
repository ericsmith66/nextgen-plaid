module SapAgent
  module InteractHelper
    LOG_PATH = Rails.root.join("agent_logs/sap.log")

    def log_interact_event(event, data = {})
      payload = {
        timestamp: Time.now.utc.iso8601,
        task_id: data[:task_id],
        correlation_id: data[:correlation_id],
        uuid: SecureRandom.uuid,
        event: event
      }.merge(data).compact

      Logger.new(LOG_PATH).info(payload.to_json)
    end

    def mac_os?
      RbConfig::CONFIG["host_os"].to_s.downcase.include?("darwin")
    end

    def write_temp_output(task_id, output)
      path = Rails.root.join("tmp", "sap_interact_#{task_id}.txt")
      File.write(path, output.to_s)
      path
    end

    module_function :log_interact_event, :mac_os?, :write_temp_output
  end
end
