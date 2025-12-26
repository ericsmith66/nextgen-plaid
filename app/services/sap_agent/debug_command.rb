module SapAgent
  class DebugCommand < Command
    def prompt
      logs = payload[:logs] || payload["logs"]
      issue = payload[:issue] || payload["issue"]
      <<~PROMPT
        You are the SAP Agent (Senior Architect and Product Manager).
        Analyze the following logs and provide a fix proposal for the issue.

        Issue: #{issue}

        Logs:
        #{logs}
      PROMPT
    end
  end
end
