module Admin
  class SapCollaborateController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :authorize_sap_collaborate
    before_action :load_or_create_sap_run

    def index
      @messages = @sap_run.sap_messages.order(:created_at)
    end

    def ask
      prompt = params[:prompt].to_s.strip

      if prompt.blank?
        @sap_run.sap_messages.create!(
          role: :assistant,
          content: "Error: prompt cannot be blank"
        )

        respond_to do |format|
          format.turbo_stream { head :ok }
          format.html { redirect_to admin_sap_collaborate_path, alert: "Prompt cannot be blank" }
        end
        return
      end

      @sap_run.sap_messages.create!(role: :user, content: prompt)
      assistant_message = @sap_run.sap_messages.create!(role: :assistant, content: "Thinking...")

      SapAgentJob.perform_later(@sap_run.id, assistant_message.id, prompt)

      respond_to do |format|
        format.turbo_stream { head :ok }
        format.html { redirect_to admin_sap_collaborate_path }
      end
    end

    private

    def authorize_sap_collaborate
      authorize :sap_collaborate, :index?
    end

    def load_or_create_sap_run
      session_key = :sap_collaborate_sap_run_id

      sap_run_id = params[:sap_run_id].presence || session[session_key]

      @sap_run = SapRun.find_by(id: sap_run_id, user_id: current_user.id) if sap_run_id.present?
      @sap_run ||= SapRun.create!(
        user: current_user,
        correlation_id: SecureRandom.uuid,
        status: "running",
        started_at: Time.current
      )

      session[session_key] = @sap_run.id
    end
  end
end
