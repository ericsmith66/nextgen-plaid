class AiFinancialAdvisor
  def self.ask(prompt, model: 'grok-4')
    smart_proxy_url = ENV['SMART_PROXY_URL'] || "http://localhost:#{ENV['SMART_PROXY_PORT'] || 4567}/proxy/generate"
    uri = URI(smart_proxy_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 300

    auth_token = ENV['PROXY_AUTH_TOKEN']

    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request['Authorization'] = "Bearer #{auth_token}" if auth_token
    request.body = {
      model: model,
      messages: [
        { role: 'user', content: prompt }
      ],
      stream: false
    }.to_json

    response = http.request(request)

    if response.code == '200'
      body = JSON.parse(response.body)
      # xAI returns content in choices[0].message.content
      # If it was proxied and already parsed by Sinatra, it might be a Hash or a String
      parsed_body = body.is_a?(String) ? JSON.parse(body) : body
      parsed_body.dig('choices', 0, 'message', 'content') || parsed_body['response']
    else
      Rails.logger.error("SmartProxy Error: #{response.code} - #{response.body}")
      "ERROR: SmartProxy returned #{response.code}"
    end
  rescue => e
    Rails.logger.error("SmartProxy Connection Error: #{e.message}")
    "ERROR: Could not connect to SmartProxy."
  end
end
