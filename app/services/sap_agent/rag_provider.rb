module SapAgent
  class RagProvider
    CONTEXT_MAP_PATH = Rails.root.join('knowledge_base/static_docs/context_map.md')
    MAX_CONTEXT_CHARS = 4000
    
    def self.build_prefix(query_type, user_id = nil)
      sap_logger.info({ event: 'RAG_PREFIX_START', query_type: query_type, user_id: user_id })
      
      docs_content = fetch_static_docs(query_type)
      snapshot_content = fetch_snapshot(user_id)
      
      full_context = <<~CONTEXT
        [CONTEXT START]
        --- STATIC DOCUMENTS ---
        #{docs_content}
        
        --- USER DATA SNAPSHOT ---
        #{snapshot_content}
        [CONTEXT END]
      CONTEXT
      
      truncated_context = truncate_context(full_context)
      
      sap_logger.info({ event: 'RAG_PREFIX_COMPLETED', length: truncated_context.length })
      truncated_context
    rescue => e
      sap_logger.warn({ event: 'RAG_PREFIX_FAILURE', error: e.message })
      "[CONTEXT ERROR: Fallback to minimal prefix]\n"
    end

    private

    def self.fetch_static_docs(query_type)
      doc_names = select_docs(query_type)
      doc_names.map do |name|
        path = Rails.root.join(name.strip)
        if File.exist?(path)
          "File: #{name}\n#{File.read(path)}\n"
        else
          sap_logger.warn({ event: 'DOC_NOT_FOUND', path: path.to_s })
          nil
        end
      end.compact.join("\n---\n")
    end

    def self.select_docs(query_type)
      return ['0_AI_THINKING_CONTEXT.md'] unless File.exist?(CONTEXT_MAP_PATH)
      
      map_content = File.read(CONTEXT_MAP_PATH)
      # Simple regex/parsing for the markdown table
      line = map_content.lines.find { |l| l.downcase.include?("| #{query_type.to_s.downcase}") }
      line ||= map_content.lines.find { |l| l.downcase.include?("| default") }
      
      if line
        docs = line.split('|')[2]
        docs ? docs.split(',').map(&:strip) : ['0_AI_THINKING_CONTEXT.md']
      else
        ['0_AI_THINKING_CONTEXT.md']
      end
    end

    def self.fetch_snapshot(user_id)
      return "No user context provided." unless user_id
      
      snapshot = Snapshot.where(user_id: user_id).last
      return "No snapshot found for user #{user_id}." unless snapshot
      
      anonymize_snapshot(snapshot.data).to_json
    end

    def self.anonymize_snapshot(data)
      # Basic anonymization as per PRD: mask balances and account-like numbers
      case data
      when Hash
        data.each_with_object({}) do |(k, v), h|
          if k.to_s.match?(/balance|amount|account_number|mask|official_name/i)
            h[k] = "[REDACTED]"
          else
            h[k] = anonymize_snapshot(v)
          end
        end
      when Array
        data.map { |v| anonymize_snapshot(v) }
      when String
        # Already handled by Anonymizer in proxy, but we do another pass here for financial values
        data.match?(/\d{4,}/) ? "[REDACTED_ID]" : data
      else
        data
      end
    end

    def self.truncate_context(text)
      return text if text.length <= MAX_CONTEXT_CHARS
      
      sap_logger.info({ event: 'CONTEXT_TRUNCATED', original_length: text.length })
      text[0...MAX_CONTEXT_CHARS] + "\n[TRUNCATED due to length limits]"
    end

    def self.sap_logger
      @sap_logger ||= Logger.new(Rails.root.join('agent_logs/sap.log'))
      @sap_logger.formatter = proc do |severity, datetime, progname, msg|
        {
          timestamp: datetime,
          severity: severity,
          message: msg
        }.to_json + "\n"
      end
      @sap_logger
    end
  end
end
