module SapAgent
  class Command
    attr_reader :payload, :logger

    def initialize(payload)
      @payload = payload
      @request_id = payload[:request_id] || SecureRandom.uuid
      @logger = Logger.new(Rails.root.join('agent_logs/sap.log'))
      @logger.formatter = proc do |severity, datetime, progname, msg|
        "[#{datetime}] #{severity}: #{msg}\n"
      end
    end

    def execute
      log_lifecycle('START')
      validate!
      
      response = call_proxy
      
      parsed_response = parse_response(response)
      log_lifecycle('COMPLETED')
      
      parsed_response
    rescue StandardError => e
      log_lifecycle('FAILURE', e.message)
      { error: e.message }
    end

    protected

    def validate!
      # Basic validation, can be overridden by subclasses
      raise "Payload must be a Hash" unless payload.is_a?(Hash)
    end

    def call_proxy
      log_lifecycle('PROXY_CALL')
      # Incorporate RAG context
      user_id = payload[:user_id] || payload["user_id"]
      query_type = self.class.name.split('::').last.gsub('Command', '').downcase
      rag_prefix = SapAgent::RagProvider.build_prefix(query_type, user_id)
      
      full_prompt = "#{rag_prefix}\n\n#{prompt}"
      
      # Route between Grok and Ollama
      model = SapAgent::Router.route(payload)

      # Pass request_id to AI call
      AiFinancialAdvisor.ask(full_prompt, model: model, request_id: @request_id)
    end

    def prompt
      raise NotImplementedError, "Subclasses must implement #prompt"
    end

    def parse_response(response)
      # Default parsing, can be overridden
      { response: response }
    end

    def log_lifecycle(status, details = nil)
      msg = "#{self.class.name} - #{status}"
      msg += ": #{details}" if details
      logger.info(msg)
    end
  end
end
