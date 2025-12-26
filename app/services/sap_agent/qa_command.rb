module SapAgent
  class QaCommand < Command
    def prompt
      question = payload[:question] || payload["question"]
      context = payload[:context] || payload["context"]
      <<~PROMPT
        You are the SAP Agent (Senior Architect and Product Manager).
        Answer the following question from the development team:
        #{question}

        Context:
        #{context}
      PROMPT
    end
  end
end
