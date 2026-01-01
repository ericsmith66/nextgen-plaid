module Admin
  class SapCollaborateController < ApplicationController
    layout "admin"

    before_action :authenticate_user!
    before_action :authorize_sap_collaborate
    before_action :prepare_ids
    before_action :load_sap_run, only: [ :index, :mission_control, :status, :pause, :resume, :artifact, :start_iterate, :start_conductor ]

    def index
      flash[:notice] = "SAP Mission Control is the new experience. Redirecting now."
      redirect_to admin_sap_mission_control_path(request.query_parameters.merge(correlation_id: @correlation_id, idempotency_uuid: @idempotency_uuid))
    end

    def mission_control
      # Always generate fresh IDs for mission_control to avoid uniqueness conflicts
      @correlation_id = SecureRandom.uuid
      @idempotency_uuid = SecureRandom.uuid
      render :mission_control
    end

    def start_iterate
      return render_missing_task if @task.blank?

      @sap_run = SapRun.create!(
        user: current_user,
        task: @task,
        status: "running",
        phase: "start",
        model_used: SapAgent::Config::MODEL_DEFAULT,
        correlation_id: @correlation_id,
        idempotency_uuid: @idempotency_uuid,
        started_at: Time.current
      )

      streamer.append_event(
        type: :user,
        title: "You",
        body: @task,
        tokens: token_badge(@task),
        phase: "start"
      )

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

      @sap_run = SapRun.create!(
        user: current_user,
        task: @task,
        status: "running",
        phase: "start",
        model_used: SapAgent::Config::MODEL_DEFAULT,
        correlation_id: @correlation_id,
        idempotency_uuid: @idempotency_uuid,
        started_at: Time.current
      )

      streamer.append_event(
        type: :user,
        title: "You",
        body: @task,
        tokens: token_badge(@task),
        phase: "start"
      )

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

    def pause
      return render_missing_task unless @sap_run

      token = SecureRandom.uuid
      @sap_run.update!(status: "paused", resume_token: token, phase: "paused")
      cache_and_broadcast(@sap_run.output_json || {}, "Paused (resume token saved)")
      flash.now[:notice] = "Paused (corr: #{@correlation_id})"
      render :mission_control
    end

    def resume
      return render_missing_task unless @sap_run

      @sap_run.update!(status: "running", phase: "resumed")
      flash.now[:notice] = "Resumed (corr: #{@correlation_id})"
      render :mission_control
    end

    def artifact
      unless @sap_run&.artifact_path
        flash[:alert] = "No artifact available for this run."
        return redirect_to admin_sap_mission_control_path(correlation_id: @correlation_id, idempotency_uuid: @idempotency_uuid)
      end

      safe_path = safe_artifact_path(@sap_run.artifact_path)
      unless safe_path && File.exist?(safe_path)
        flash[:alert] = "Artifact file not found or not accessible."
        return redirect_to admin_sap_mission_control_path(correlation_id: @correlation_id, idempotency_uuid: @idempotency_uuid)
      end

      send_file safe_path, disposition: :attachment
    end

    def status
      last_event_id = params[:last_event_id]
      summary = streamer.summary
      events = last_event_id.present? ? streamer.events_after(last_event_id) : streamer.events

      render json: summary.merge(
        correlation_id: @correlation_id,
        events: events
      )
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

    def load_sap_run
      @sap_run = SapRun.find_by(correlation_id: @correlation_id)
      @sap_runs = SapRun.order(started_at: :desc).page(params[:page]).per(20)
      current_status = @sap_run&.status
      @pause_disabled = @sap_run.nil? || %w[paused complete failed aborted].include?(current_status)
      @resume_disabled = @sap_run.nil? || %w[running complete failed aborted].include?(current_status)
    end

    def render_response(response, notice:)
      @sap_response = response
      @humanized_response = humanize_response(response)
      cache_and_broadcast(@sap_response, @humanized_response)
      streamer.ingest_payload(@sap_response)
      if @humanized_response.present?
        streamer.append_event(
          type: :system,
          title: "Summary",
          body: @humanized_response,
          phase: @sap_response.is_a?(Hash) ? (@sap_response[:phase] || @sap_response["phase"]) : nil,
          tokens: token_badge(@humanized_response),
          raw: @sap_response
        )
      end
      update_sap_run(@sap_response)
      head :no_content
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
        status: payload.is_a?(Hash) ? (payload[:status] || payload["status"] || "complete") : "complete",
        payload: payload,
        humanized: humanized,
        updated_at: Time.current
      }

      Rails.cache.write(cache_key, body, expires_in: 1.hour)
      SapRunChannel.broadcast_to(@correlation_id, body)
      streamer.ingest_payload(payload)
    end

    def update_sap_run(payload)
      return unless @sap_run

      status = payload.is_a?(Hash) ? (payload[:status] || payload["status"]) : "complete"
      error_message = payload.is_a?(Hash) ? (payload[:error] || payload["error"] || payload[:reason] || payload["reason"]) : nil
      model_used = payload.is_a?(Hash) ? (payload[:model_used] || payload["model_used"]) : nil
      artifact_path = payload.is_a?(Hash) ? (payload[:artifact_path] || payload["artifact_path"]) : nil

      # Normalize status: "completed" -> "complete"
      status = normalize_status(status)

      Rails.logger.info "[SAP] update_sap_run: correlation_id=#{@correlation_id}, raw_status=#{payload.is_a?(Hash) ? (payload[:status] || payload['status']) : 'N/A'}, normalized_status=#{status}"

      attrs = {
        status: status || "complete",
        output_json: payload.is_a?(Hash) ? payload : nil,
        model_used: model_used || @sap_run.model_used,
        error_message: error_message,
        phase: payload.is_a?(Hash) ? (payload[:phase] || payload["phase"]) : nil
      }

      attrs[:artifact_path] = artifact_path if artifact_path.present?

      attrs[:completed_at] = Time.current if %w[complete aborted failed error].include?(attrs[:status].to_s)

      Rails.logger.info "[SAP] update_sap_run: about to update with attrs[:status]=#{attrs[:status]}"
      @sap_run.update!(attrs)
      Rails.logger.info "[SAP] update_sap_run: successfully updated to status=#{@sap_run.status}"
    rescue StandardError => e
      Rails.logger.error "[SAP] update_sap_run ERROR: #{e.class.name}: #{e.message}, correlation_id=#{@correlation_id}, attempted_status=#{attrs[:status]}"
      raise
    end

    def normalize_status(status)
      return "complete" if status.nil? || status.to_s.strip.empty?

      normalized = status.to_s.strip.downcase
      # Map common variations to valid enum values
      case normalized
      when "completed"
        "complete"
      when "pending", "running", "paused", "complete", "failed", "aborted"
        normalized
      else
        Rails.logger.warn "[SAP] normalize_status: unknown status '#{status}', defaulting to 'complete'"
        "complete"
      end
    end

    def cache_key
      "sap_run:#{@correlation_id}"
    end

    def sap_run_payload
      return unless @sap_run

      {
        status: @sap_run.status,
        phase: @sap_run.phase,
        model_used: @sap_run.model_used,
        payload: @sap_run.output_json,
        humanized: summarize_hash(@sap_run.output_json || {}),
        updated_at: @sap_run.updated_at
      }
    end

    def safe_artifact_path(path)
      return nil if path.blank?
      candidate = Pathname.new(path)
      root = Rails.root
      allowed = [ root.join("agent_logs"), root.join("knowledge_base") ]
      return nil unless allowed.any? { |p| candidate.expand_path.to_s.start_with?(p.to_s) }
      candidate.to_s
    rescue
      nil
    end

    def render_missing_task
      flash.now[:alert] = "Task is required"
      render :index, status: :unprocessable_entity
    end

    def render_error(error)
      flash.now[:alert] = "There was a problem starting the agent: #{error.message}"
      render :index, status: :internal_server_error
    end

    def streamer
      @streamer ||= SapRunStream.new(correlation_id: @correlation_id)
    end

    def token_badge(text)
      return nil if text.blank?

      used = SapAgent.estimate_tokens(text)
      remaining = [ SapAgent::Config::ADAPTIVE_TOKEN_BUDGET - used, 0 ].max
      { used: used, remaining: remaining }
    end
  end
end
