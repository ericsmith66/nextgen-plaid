# frozen_string_literal: true

module Ai
  class RoutingPolicy
    POLICY_VERSION = "50f-v1"

    Decision = Struct.new(
      :model_id,
      :use_live_search,
      :max_loops,
      :reason,
      :policy_version,
      keyword_init: true
    )

    # Inputs:
    # - prompt/messages: content to route
    # - research_requested: explicit flag from caller
    # - requires_live_data: optional hint
    # - privacy_level: optional hint ("high" forces local)
    # - task_type/max_cost_tier: reserved for future extensions
    def self.call(
      prompt: nil,
      messages: nil,
      task_type: nil,
      requires_live_data: nil,
      privacy_level: nil,
      max_cost_tier: nil,
      research_requested: false
    )
      text = extract_text(prompt: prompt, messages: messages)
      token_estimate = estimate_tokens(text)
      complex = complex_task?(text)
      use_live_search = !!research_requested || !!requires_live_data

      if privacy_level.to_s.downcase == "high"
        return Decision.new(
          model_id: "ollama",
          use_live_search: false,
          max_loops: 0,
          reason: "privacy_level=high forces local-only model",
          policy_version: POLICY_VERSION
        )
      end

      if max_cost_tier.to_s.downcase == "low" && use_live_search
        return Decision.new(
          model_id: ENV.fetch("AI_COMPLEX_MODEL", "grok-4"),
          use_live_search: true,
          max_loops: 1,
          reason: "max_cost_tier=low allows live search but limits tool loops to 1",
          policy_version: POLICY_VERSION
        )
      end

      if max_cost_tier.to_s.downcase == "low"
        return Decision.new(
          model_id: "ollama",
          use_live_search: false,
          max_loops: 0,
          reason: "max_cost_tier=low prefers local-only model",
          policy_version: POLICY_VERSION
        )
      end

      if token_estimate < token_threshold && !use_live_search && !complex
        Decision.new(
          model_id: "ollama",
          use_live_search: false,
          max_loops: 0,
          reason: "simple prompt (estimate=#{token_estimate} tokens)",
          policy_version: POLICY_VERSION
        )
      else
        rationale = if complex
          "complex artifact generation"
        elsif use_live_search
          "live search requested"
        else
          "estimate=#{token_estimate} exceeds threshold=#{token_threshold}"
        end

        Decision.new(
          model_id: ENV.fetch("AI_COMPLEX_MODEL", "grok-4"),
          use_live_search: use_live_search,
          max_loops: nil,
          reason: rationale,
          policy_version: POLICY_VERSION
        )
      end
    end

    def self.token_threshold
      Integer(ENV.fetch("TOKEN_THRESHOLD", "1000"))
    end

    def self.extract_text(prompt:, messages:)
      return prompt.to_s if prompt

      Array(messages).filter_map do |m|
        if m.is_a?(Hash)
          m[:content] || m["content"]
        else
          nil
        end
      end.join("\n")
    end
    private_class_method :extract_text

    def self.complex_task?(text)
      text.to_s.downcase.match?(/\b(prd|epic|artifact|acceptance criteria|requirements)\b/)
    end
    private_class_method :complex_task?

    def self.estimate_tokens(text)
      prompt_overhead = 500
      (text.to_s.strip.length / 3.5).ceil + prompt_overhead
    end
    private_class_method :estimate_tokens
  end
end
