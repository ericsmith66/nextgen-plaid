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
                    elsif token_estimate >= TOKEN_THRESHOLD
                      "Query > TOKEN_THRESHOLD (#{token_estimate} > #{TOKEN_THRESHOLD})"
                    else
                      "Research required: #{needs_research}"
                    end
        log_decision('GROK', "Cost/Privacy Escalation - #{rationale}")
        'grok-4'
      end
    end

    private

    def self.estimate_tokens(text)
      # Refined heuristic: account for prompt overhead and better whitespace handling
      # Roughly 1 token per 3.5 characters to be more conservative
      prompt_overhead = 500
      (text.strip.length / 3.5).ceil + prompt_overhead
    end

    def self.log_decision(model, rationale)
      logger = Logger.new(Rails.root.join('agent_logs/sap.log'))
      logger.info("ROUTER - Decision: #{model} | Rationale: #{rationale}")
    end
  end
end
