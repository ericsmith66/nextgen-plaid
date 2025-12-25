class Agents::MonitorController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_owner!

  def index
    @logs = AgentLog.order(created_at: :desc).limit(50)
    @queues = {
      "sap_to_cwa" => SolidQueue::Job.where(queue_name: "sap_to_cwa").count,
      "cwa_to_cso" => SolidQueue::Job.where(queue_name: "cwa_to_cso").count,
      "cso_to_cwa" => SolidQueue::Job.where(queue_name: "cso_to_cwa").count
    }
  end

  private

  def ensure_owner!
    # Simple owner check for POC
    authorized_emails = %w[ ericsmith@gmail.com ericsmith66@me.com ]
    unless authorized_emails.include?(current_user.email)
      redirect_to root_path, alert: "Not authorized."
    end
  end
end
