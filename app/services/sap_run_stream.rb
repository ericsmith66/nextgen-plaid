# frozen_string_literal: true

class SapRunStream
  CACHE_TTL = 2.hours
  MAX_EVENTS = 200

  def initialize(correlation_id:, cache: Rails.cache)
    @correlation_id = correlation_id
    @cache = cache
  end

  def summary
    cached = @cache.read(summary_key)
    return cached.deep_symbolize_keys if cached.present?

    base_summary
  end

  def events
    @cache.read(events_key)&.map { |e| e.deep_symbolize_keys } || []
  end

  def events_after(last_id)
    list = events
    return list if last_id.blank?

    idx = list.index { |e| e[:id] == last_id }
    return list if idx.nil?

    list[(idx + 1)..] || []
  end

  def append_event(type:, title:, body:, phase: nil, tokens: nil, raw: nil, status: nil, error: nil, meta: {})
    event = {
      id: SecureRandom.uuid,
      correlation_id: @correlation_id,
      type: type.to_sym,
      title: title,
      body: body,
      phase: phase,
      tokens: normalize_tokens(tokens),
      raw: raw,
      status: status,
      error: error,
      meta: meta,
      created_at: Time.current.iso8601
    }

    event[:html] = render_event(event)

    list = (events + [ event ]).last(MAX_EVENTS)
    @cache.write(events_key, list, expires_in: CACHE_TTL)
    @cache.write(summary_key, build_summary(list, status: status), expires_in: CACHE_TTL)

    broadcast_event(event)
    Rails.logger.info("[sap_run][#{@correlation_id}] append_event type=#{event[:type]} phase=#{phase} status=#{status} error=#{error.present?}")

    event
  end

  def ingest_payload(payload)
    return unless payload

    normalized = payload.is_a?(Hash) ? payload.deep_symbolize_keys : { value: payload }
    status = normalized[:status]
    phase = normalized[:phase]
    error = normalized[:error] || normalized[:reason]

    # iteration bubbles
    Array(normalized[:iterations]).each do |iter|
      iter_hash = iter.deep_symbolize_keys
      iter_body = iter_hash[:output] || iter_hash[:state]
      append_event(
        type: :phase,
        title: "Iteration #{iter_hash[:iteration] || '?'}",
        body: iter_body || "Iteration update",
        phase: "iteration",
        tokens: token_estimate(iter_body),
        raw: iter_hash,
        status: status
      )
    end

    if normalized[:final_output]
      append_event(
        type: :agent,
        title: "Agent",
        body: normalized[:final_output],
        phase: phase || status,
        tokens: token_estimate(normalized[:final_output]),
        raw: normalized,
        status: status
      )
    elsif normalized[:value]
      append_event(
        type: :agent,
        title: "Agent",
        body: normalized[:value].to_s,
        phase: phase || status,
        tokens: token_estimate(normalized[:value]),
        raw: normalized,
        status: status
      )
    end

    if error
      append_event(
        type: :error,
        title: "Error",
        body: humanized_error(error),
        phase: phase || status,
        tokens: nil,
        raw: normalized,
        status: status,
        error: true
      )
    end

    @cache.write(summary_key, build_summary(events, status: status), expires_in: CACHE_TTL)
  end

  def log_poll(latency_ms:, ok:, error: nil)
    Rails.logger.info("[sap_run][#{@correlation_id}] poll latency_ms=#{latency_ms} ok=#{ok} error=#{error&.message}")
  end

  private

  def token_estimate(text)
    return nil if text.blank?

    used = SapAgent.estimate_tokens(text)
    budget = SapAgent::Config::ADAPTIVE_TOKEN_BUDGET
    remaining = [ budget - used, 0 ].max
    { used: used, remaining: remaining }
  end

  def normalize_tokens(tokens)
    return nil if tokens.nil?

    if tokens.is_a?(Hash)
      used = tokens[:used] || tokens["used"]
      remaining = tokens[:remaining] || tokens["remaining"]
      return { used: used&.to_i, remaining: remaining&.to_i } if used || remaining
    end

    token_estimate(tokens)
  end

  def build_summary(list, status: nil)
    typed = list.map { |e| e.deep_symbolize_keys }
    last_phase = typed.reverse.find { |e| e[:phase].present? }&.dig(:phase)
    prompt = typed.find { |e| e[:type] == :user }&.dig(:body)
    response = typed.reverse.find { |e| %i[agent system].include?(e[:type]) }&.dig(:body)
    tokens = typed.reverse.find { |e| e[:tokens].present? }&.dig(:tokens)
    error = typed.reverse.find { |e| e[:type] == :error }

    {
      correlation_id: @correlation_id,
      status: status || typed.reverse.find { |e| e[:status].present? }&.dig(:status) || "running",
      phase: last_phase,
      prompt: prompt,
      response: response,
      tokens: tokens,
      error: error&.dig(:body),
      updated_at: Time.current.iso8601,
      events: typed.last(20)
    }
  end

  def render_event(event)
    ApplicationController.render(partial: "sap_runs/stream_event", locals: { event: event })
  end

  def broadcast_event(event)
    # Turbo::StreamsChannel.broadcast_append_to(
    #   @correlation_id,
    #   target: "chat-stream",
    #   partial: "sap_runs/stream_event",
    #   locals: { event: event }
    # )
    # TODO: Install turbo-rails gem or use ActionCable directly
  end

  def base_summary
    {
      correlation_id: @correlation_id,
      status: "pending",
      phase: nil,
      prompt: nil,
      response: nil,
      tokens: { used: 0, remaining: SapAgent::Config::ADAPTIVE_TOKEN_BUDGET },
      error: nil,
      updated_at: nil,
      events: []
    }
  end

  def humanized_error(error)
    <<~TEXT.squish
      #{error}. You can retry the request or switch the model to recover.
    TEXT
  end

  def summary_key
    "sap_run:summary:#{@correlation_id}"
  end

  def events_key
    "sap_run:events:#{@correlation_id}"
  end
end
