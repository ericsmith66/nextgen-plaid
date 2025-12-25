class AgentQueueJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: 2.seconds, attempts: 3

  def perform(task_id, payload)
    user_id = payload["user_id"]

    case queue_name
    when "sap_to_cwa"
      CwaAgent.new.process_prd(task_id, user_id, payload["prd"])
    when "cwa_to_cso"
      CsoAgent.new.evaluate_commands(task_id, user_id, payload["commands"])
    when "cso_to_cwa"
      CwaAgent.new.handle_security_feedback(task_id, user_id, payload["evaluation"])
    else
      Rails.logger.warn("Unknown queue: #{queue_name}")
    end

    Rails.logger.info({
      event: "agent_queue.process",
      task_id: task_id,
      queue: queue_name,
      timestamp: Time.current
    }.to_json)
  end
end
