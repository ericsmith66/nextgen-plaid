require 'faraday'
require 'json'

class OllamaClient
  DEFAULT_URL = 'http://localhost:11434/api/chat'

  def initialize(url: nil)
    @url = url || ENV['OLLAMA_URL'] || DEFAULT_URL
  end

  def chat(payload)
    # Map Grok-style payload to Ollama-style if needed
    # Grok: { model: '...', messages: [...] }
    # Ollama: { model: '...', messages: [...], stream: false }
    
    ollama_payload = {
      model: payload['model'] == 'ollama' ? (ENV['OLLAMA_MODEL'] || 'llama3.1:8b') : payload['model'],
      messages: payload['messages'],
      stream: false
    }

    connection.post('') do |req|
      req.body = ollama_payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  def connection
    @connection ||= Faraday.new(url: @url) do |f|
      f.request :json
      f.adapter Faraday.default_adapter
    end
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }
    
    OpenStruct.new(status: status, body: body)
  end
end
