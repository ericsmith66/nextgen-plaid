class AiFinancialAdvisor
  class << self
    def ask(prompt, model: "grok-4", request_id: nil)
      response = chat_completions(
        messages: [ { role: "user", content: prompt } ],
        model: model,
        request_id: request_id
      )

      response.dig("choices", 0, "message", "content") || response.dig("message", "content") || response["response"]
    end

    # Calls SmartProxy's OpenAI-compatible endpoint so callers can read tool-loop metadata.
    # Returns the parsed OpenAI-shaped response hash.
    def chat_completions(messages:, model:, request_id: nil, tools: nil, max_loops: nil)
      uri = URI(smart_proxy_openai_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 300

      auth_token = ENV["PROXY_AUTH_TOKEN"]

      request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
      request["Authorization"] = "Bearer #{auth_token}" if auth_token
      request["X-Request-ID"] = request_id if request_id
      request["X-SmartProxy-Max-Loops"] = max_loops.to_i.to_s if max_loops

      payload = {
        model: model,
        messages: messages,
        stream: false
      }
      payload[:tools] = tools if tools

      request.body = payload.to_json
      response = http.request(request)

      if response.code == "200"
        body = JSON.parse(response.body)
        body.is_a?(String) ? JSON.parse(body) : body
      else
        Rails.logger.error("SmartProxy Error: #{response.code} - #{response.body}")
        { "error" => "SmartProxy returned #{response.code}", "status" => response.code.to_i }
      end
    rescue StandardError => e
      Rails.logger.error("SmartProxy Connection Error: #{e.message}")
      { "error" => "Could not connect to SmartProxy", "message" => e.message }
    end

    private

    def smart_proxy_openai_url
      base = ENV["SMART_PROXY_OPENAI_BASE"]
      return "#{base}/chat/completions" if base.present?

      port = ENV.fetch("SMART_PROXY_PORT", Rails.env.test? ? "3002" : "3001")
      "http://localhost:#{port}/v1/chat/completions"
    end
  end
end
