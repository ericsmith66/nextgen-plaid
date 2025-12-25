class AiFinancialAdvisor
  OLLAMA_URL = 'http://localhost:11434/api/generate'

  def self.ask(prompt, model: 'llama3.1:70b')
    uri = URI(OLLAMA_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 300

    request = Net::HTTP::Post.new(uri, 'Content-Type' => 'application/json')
    request.body = {
      model: model,
      prompt: prompt,
      stream: false
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)['response']
  rescue => e
    Rails.logger.error("Ollama Error: #{e.message}")
    "ERROR: Could not connect to Ollama."
  end
end
