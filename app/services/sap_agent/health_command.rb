module SapAgent
  class HealthCommand < Command
    def execute
      log_lifecycle('START')
      
      results = {
        timestamp: Time.current,
        smart_proxy: check_proxy,
        ollama: check_ollama,
        grok: check_grok
      }
      
      log_lifecycle('COMPLETED')
      results
    rescue => e
      log_lifecycle('FAILURE', e.message)
      { error: e.message }
    end

    private

    def check_proxy
      uri = URI(ENV['SMART_PROXY_URL'] || "http://localhost:#{ENV['SMART_PROXY_PORT'] || 4567}/health")
      # Fix URI if it's the generate endpoint
      uri.path = '/health' if uri.path == '/proxy/generate'
      
      response = Net::HTTP.get_response(uri)
      response.code == '200' ? "OK" : "Error: #{response.code}"
    rescue => e
      "Connection Failed: #{e.message}"
    end

    def check_ollama
      AiFinancialAdvisor.ask("Hello, respond with exactly 'OK'", model: 'ollama') == "OK" ? "OK" : "Unexpected Response"
    rescue => e
      "Failed: #{e.message}"
    end

    def check_grok
      # Only check Grok if API key is set to avoid unnecessary 401s
      return "Skipped (No API Key)" if ENV['GROK_API_KEY_SAP'].blank? && ENV['GROK_API_KEY'].blank?
      
      AiFinancialAdvisor.ask("Hello, respond with exactly 'OK'", model: 'grok-4') == "OK" ? "OK" : "Unexpected Response"
    rescue => e
      "Failed: #{e.message}"
    end

    def prompt
      # Not used for health check
      ""
    end
  end
end
