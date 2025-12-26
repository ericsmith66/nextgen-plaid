require 'faraday'
require 'faraday/retry'
require 'json'

require 'ostruct'

class GrokClient
  BASE_URL = 'https://api.x.ai/v1'

  def initialize(api_key:)
    @api_key = api_key
  end

  def chat_completions(payload)
    connection.post('chat/completions') do |req|
      req.body = payload.to_json
    end
  rescue Faraday::Error => e
    handle_error(e)
  end

  private

  def connection
    @connection ||= Faraday.new(url: BASE_URL) do |f|
      f.request :json
      f.request :retry, {
        max: 3,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [ 429, 500, 502, 503, 504 ]
      }
      f.headers['Authorization'] = "Bearer #{@api_key}"
      f.headers['Content-Type'] = 'application/json'
      f.adapter Faraday.default_adapter
    end
  end

  def handle_error(error)
    status = error.response ? error.response[:status] : 500
    body = error.response ? error.response[:body] : { error: error.message }
    
    OpenStruct.new(status: status, body: body)
  end
end
