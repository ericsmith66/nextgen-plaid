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

    def status
      payload = Rails.cache.read(cache_key)
      if payload
        render json: payload.merge(correlation_id: @correlation_id)
      else
        render json: { correlation_id: @correlation_id, status: "unknown" }, status: :not_found
      end
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
      cache_and_broadcast(@sap_response, @humanized_response)
      flash.now[:notice] = "#{notice} (corr: #{@correlation_id})"
      render :index
    end

    def humanize_response(payload)
      return if payload.blank?

      return summarize_hash(payload) if payload.is_a?(Hash)
      return payload if payload.is_a?(String)

      safe_fallback_summary(payload)
    rescue StandardError
      nil
    end

    def safe_fallback_summary(payload)
      text = payload.is_a?(String) ? payload : payload.to_json
      text&.truncate(280)
    end

    def summarize_hash(payload)
      status = payload[:status] || payload["status"]
      reason = payload[:reason] || payload["reason"]
      iterations = payload[:iterations] || payload["iterations"]
      iter_count = iterations.respond_to?(:size) ? iterations.size : nil
      model = payload[:model_used] || payload["model_used"]

      parts = []
      parts << "Status: #{status}" if status
      parts << "Reason: #{reason}" if reason
      parts << "Iterations: #{iter_count}" if iter_count
      parts << "Model: #{model}" if model
      return parts.join(" | ") if parts.any?

      safe_fallback_summary(payload)
    end

    def cache_and_broadcast(payload, humanized)
      body = {
        correlation_id: @correlation_id,
        idempotency_uuid: @idempotency_uuid,
        status: payload.is_a?(Hash) ? (payload[:status] || payload["status"] || "completed") : "completed",
        payload: payload,
        humanized: humanized,
        updated_at: Time.current
      }

      Rails.cache.write(cache_key, body, expires_in: 1.hour)
      SapRunChannel.broadcast_to(@correlation_id, body)
    end

    def cache_key
      "sap_run:#{@correlation_id}"
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
