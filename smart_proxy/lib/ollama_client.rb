require 'faraday'
require 'json'
require 'ostruct'

class OllamaClient
  DEFAULT_URL = 'http://localhost:11434/api/chat'
  DEFAULT_TAGS_URL = 'http://localhost:11434/api/tags'

  def initialize(url: nil)
    @url = url || ENV['OLLAMA_URL'] || DEFAULT_URL
  end

  def list_models
    resp = tags_connection.get('')
    OpenStruct.new(status: resp.status, body: resp.body)
  rescue Faraday::Error => e
    handle_error(e)
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

  def tags_connection
    @tags_connection ||= Faraday.new(url: ENV['OLLAMA_TAGS_URL'] || DEFAULT_TAGS_URL) do |f|
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
