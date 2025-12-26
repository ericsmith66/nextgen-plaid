module SapAgent
  class GenerateCommand < Command
    def prompt
      query = payload[:query] || payload["query"]
      <<~PROMPT
        You are the SAP Agent (Senior Architect and Product Manager).
        Generate a detailed Markdown PRD/Epic for the following request:
        #{query}
        
        Focus on technical architecture, data models, and functional requirements.
      PROMPT
    end
  end
end
