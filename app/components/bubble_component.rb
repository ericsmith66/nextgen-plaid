# frozen_string_literal: true

class BubbleComponent < ViewComponent::Base
  TYPES = {
    user:   { label: "You", tone: :primary, align: :end },
    agent:  { label: "Agent", tone: :secondary, align: :start },
    system: { label: "System", tone: :info, align: :start },
    error:  { label: "Error", tone: :error, align: :start },
    token:  { label: "Tokens", tone: :accent, align: :start },
    phase:  { label: "Phase", tone: :warning, align: :start }
  }.freeze

  def initialize(type:, title: nil, body: nil, tokens: nil, phase: nil, raw_payload: nil, correlation_id: nil)
    @type = type.to_sym
    @title = title
    @body = body
    @tokens = tokens
    @phase = phase
    @raw_payload = raw_payload
    @correlation_id = correlation_id
  end

  def align_class
    bubble_config[:align] == :end ? "chat chat-end" : "chat chat-start"
  end

  def bubble_classes
    ["chat-bubble", tone_class, "shadow-sm"].compact.join(" ")
  end

  def label
    @title.presence || bubble_config[:label] || "System"
  end

  def body
    @body.presence || content
  end

  def badge
    @type.to_s.titleize
  end

  def phase_badge
    return unless @phase.present?

    "Phase: #{@phase}"
  end

  def tokens_badge
    return unless @tokens.present?

    used = @tokens[:used] || @tokens["used"]
    remaining = @tokens[:remaining] || @tokens["remaining"]

    parts = []
    parts << "Used: #{used}" if used
    parts << "Remaining: #{remaining}" if remaining
    parts.presence&.join(" · ")
  end

  def correlation_label
    @correlation_id
  end

  def raw_payload
    @raw_payload
  end

  def pretty_raw_payload
    return unless raw_payload

    JSON.pretty_generate(raw_payload)
  rescue StandardError
    raw_payload.to_s
  end

  private

  def bubble_config
    TYPES.fetch(@type, TYPES[:system])
  end

  def tone_class
    case bubble_config[:tone]
    when :primary then "chat-bubble-primary text-primary-content"
    when :secondary then "chat-bubble-secondary text-secondary-content"
    when :info then "chat-bubble-info text-info-content"
    when :accent then "chat-bubble-accent text-accent-content"
    when :warning then "chat-bubble-warning text-warning-content"
    when :error then "chat-bubble-error text-error-content"
    else
      ""
    end
  end
end
