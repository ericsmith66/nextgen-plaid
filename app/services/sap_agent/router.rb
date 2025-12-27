module SapAgent
  class Router
    TOKEN_THRESHOLD = ENV['TOKEN_THRESHOLD']&.to_i || 1000

    def self.route(payload)
      query = payload[:query] || ""
      token_estimate = estimate_tokens(query)
      needs_research = !!payload[:research]
      
      # PRD/Epic generation is complex; default to GROK unless it's a simple backlog task
      is_complex_task = query.downcase.match?(/prd|epic|artifact/)

      if token_estimate < TOKEN_THRESHOLD && !needs_research && !is_complex_task
        log_decision('OLLAMA', "Estimate: #{token_estimate} tokens, Simple task")
        'ollama'
      else
        rationale = if is_complex_task
                      "Complex artifact generation (PRD/Epic)"
                    else
                      "Estimate: #{token_estimate} tokens, Research: #{needs_research}"
                    end
        log_decision('GROK', rationale)
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
