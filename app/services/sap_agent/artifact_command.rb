require 'erb'

module SapAgent
  class ArtifactCommand < Command
    PROMPT_PATH = Rails.root.join('config/agent_prompts/sap_system.md')
    BACKLOG_PATH = Rails.root.join('knowledge_base/backlog.json')
    MCP_PATH = Rails.root.join('knowledge_base/static_docs/MCP.md')

    def validate!
      super
      raise "Strategy required" unless payload[:strategy]
    end

    def prompt
      system_prompt_template = File.read(PROMPT_PATH)
      mcp_content = File.exist?(MCP_PATH) ? File.read(MCP_PATH) : "No vision context."
      backlog_content = File.exist?(BACKLOG_PATH) ? File.read(BACKLOG_PATH) : "[]"
      rag_context = fetch_rag_context

      # Use ERB for dynamic substitutions in the system prompt
      # We define the context variables that ERB will use
      context = {
        backlog: backlog_content,
        vision: mcp_content,
        project_context: rag_context
      }

      # Replace placeholders [CONTEXT_BACKLOG] and [VISION_SSOT] for backward compatibility
      # while supporting ERB <%= vision %> and <%= backlog %>
      rendered_system_prompt = system_prompt_template
                               .gsub('[CONTEXT_BACKLOG]', context[:backlog])
                               .gsub('[VISION_SSOT]', context[:vision])
                               .gsub('[PROJECT_CONTEXT]', context[:project_context].to_json)

      # Also support ERB rendering if <%= is present
      if rendered_system_prompt.include?('<%=')
        template = ERB.new(rendered_system_prompt)
        rendered_system_prompt = template.result_with_hash(context)
      end

      "#{rendered_system_prompt}\n\nUser Request: #{payload[:query]}"
    end

    def execute
      log_lifecycle('START')
      validate!
      
      # Optional: Perform research if needed
      if payload[:research]
        log_lifecycle('RESEARCH_START')
        research_results = SapAgent::SmartProxyClient.research(payload[:query], request_id: @request_id)
        @payload[:research_results] = research_results
        log_lifecycle('RESEARCH_COMPLETED', "Confidence: #{research_results[:confidence]}")
      end

      attempts = 0
      max_attempts = 3 # 1 original + 2 retries
      last_error = nil
      
      while attempts < max_attempts
        begin
          log_lifecycle("ATTEMPT_#{attempts + 1}")
          response = call_proxy
          
          # Strategies will define validation logic
          validate_artifact!(response)
          
          parsed_response = parse_response(response)
          store_artifact(parsed_response)
          
          log_lifecycle('COMPLETED')
          return parsed_response
        rescue StandardError => e
          attempts += 1
          last_error = e.message
          log_lifecycle("RETRY_#{attempts}", e.message)
          # Update payload or prompt for fix-it attempt? 
          # For now, we'll just retry, but ideally we'd append the error to the prompt.
          @payload[:query] = "FIX PREVIOUS ERROR: #{e.message}\nORIGINAL REQUEST: #{@payload[:query]}" if attempts < max_attempts
        end
      end
      
      log_lifecycle('FAILURE', last_error)
      { error: "Failed after #{max_attempts} attempts: #{last_error}" }
    end

    private

    def fetch_rag_context
      snapshot_path = Dir.glob(Rails.root.join('knowledge_base/snapshots/*-project-snapshot.json')).max
      return {} unless snapshot_path && File.exist?(snapshot_path)

      JSON.parse(File.read(snapshot_path))
    rescue => e
      Rails.logger.warn("RAG context fetch failed: #{e.message}")
      {}
    end

    protected

    def validate_artifact!(response)
      # Strategy-specific validation
      strategy_module.validate_output!(response)
    end

    def parse_response(response)
      strategy_module.parse_output(response)
    end

    def store_artifact(data)
      strategy_module.store!(data)
    end

    private

    def strategy_module
      @strategy_module ||= begin
        strategy_name = payload[:strategy].to_s.classify
        "SapAgent::#{strategy_name}Strategy".constantize
      rescue NameError
        raise "Unknown strategy: #{payload[:strategy]}"
      end
    end
  end
end
