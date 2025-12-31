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

  def initialize(type:, title: nil, body: nil)
    @type = type.to_sym
    @title = title
    @body = body
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
