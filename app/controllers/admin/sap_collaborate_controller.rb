module Admin
  class SapCollaborateController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :authorize_sap_collaborate
    before_action :prepare_ids

    def index
    end

    def start_iterate
      return render_missing_task if @task.blank?

      response = SapAgent.iterate_prompt(
        task: @task,
        branch: @branch,
        correlation_id: @correlation_id
      )

      render_response(response, notice: "Adaptive Iterate started (#{@correlation_id})")
    rescue StandardError => e
      render_error(e)
    end

    def start_conductor
      return render_missing_task if @task.blank?

      response = SapAgent.conductor(
        task: @task,
        branch: @branch,
        correlation_id: @correlation_id,
        idempotency_uuid: @idempotency_uuid
      )

      render_response(response, notice: "Conductor started (#{@correlation_id})")
    rescue StandardError => e
      render_error(e)
    end

    private

    def authorize_sap_collaborate
      authorize :sap_collaborate, :index?
    end

    def prepare_ids
      @task = params[:task]
      @branch = params[:branch]
      @correlation_id = params[:correlation_id].presence || SecureRandom.uuid
      @idempotency_uuid = params[:idempotency_uuid].presence || SecureRandom.uuid
    end

    def render_response(response, notice:)
      @sap_response = response
      @humanized_response = humanize_response(response)
      flash.now[:notice] = "#{notice} (corr: #{@correlation_id})"
      render :index
    end

    def humanize_response(payload)
      return if payload.blank?

      SapAgent::RagProvider.summarize("Summarize in English: #{payload.to_json}") || safe_fallback_summary(payload)
    rescue StandardError
      nil
    end

    def safe_fallback_summary(payload)
      text = payload.is_a?(String) ? payload : payload.to_json
      text&.truncate(280)
    end

    def render_missing_task
      flash.now[:alert] = "Task is required"
      render :index, status: :unprocessable_entity
    end

    def render_error(error)
      flash.now[:alert] = "There was a problem starting the agent: #{error.message}"
      render :index, status: :internal_server_error
    end
  end
end
