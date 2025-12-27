module SapAgent
  class Router
    TOKEN_THRESHOLD = ENV['TOKEN_THRESHOLD']&.to_i || 1000

    def self.route(payload)
      query = payload[:query] || ""
      token_estimate = estimate_tokens(query)
      needs_research = !!payload[:research]

      if token_estimate < TOKEN_THRESHOLD && !needs_research
        log_decision('OLLAMA', "Estimate: #{token_estimate} tokens, No research needed")
        'ollama'
      else
        log_decision('GROK', "Estimate: #{token_estimate} tokens, Research: #{needs_research}")
        'grok-4'
      end
    end

    private

    def self.estimate_tokens(text)
      # Very rough estimate: 1 token ~= 4 characters for English
      (text.length / 4.0).ceil
    end

    def self.log_decision(model, rationale)
      logger = Logger.new(Rails.root.join('agent_logs/sap.log'))
      logger.info("ROUTER - Decision: #{model} | Rationale: #{rationale}")
    end
  end
end
