require 'sinatra/base'
require 'json'
require 'logger'
require 'dotenv'
Dotenv.load(File.expand_path('../.env', __dir__))
require_relative 'lib/grok_client'
require_relative 'lib/ollama_client'
require_relative 'lib/tool_client'
require_relative 'lib/anonymizer'
require 'securerandom'
require 'time'

class SmartProxyApp < Sinatra::Base
  configure do
    disable :protection
    set :port, ENV['SMART_PROXY_PORT'] || 4567
    set :bind, '0.0.0.0'
    set :logging, true
    set :protection, false
    
    # Setup structured JSON logging
    log_dir = File.join(settings.root, '..', 'log')
    Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
    log_file = File.join(log_dir, 'smart_proxy.log')
    $logger = Logger.new(log_file, 'daily')
    $logger.formatter = proc do |severity, datetime, _progname, msg|
      {
        timestamp: datetime,
        severity: severity,
        message: msg
      }.to_json + "\n"
    end

    # In-memory cache for model listing (best-effort)
    set :models_cache_ttl, Integer(ENV.fetch('SMART_PROXY_MODELS_CACHE_TTL', '60'))
    set :models_cache, { fetched_at: Time.at(0), data: nil }
  end

  before do
    content_type :json
    @session_id = request.env['HTTP_X_REQUEST_ID'] || SecureRandom.uuid
    authenticate! unless request.path_info == '/health'
  end

  get '/health' do
    { status: 'ok' }.to_json
  end

  # OpenAI-compatible model listing endpoint.
  # Backed by Ollama's HTTP API (`GET /api/tags`).
  get '/v1/models' do
    begin
      cached = settings.models_cache
      ttl = settings.models_cache_ttl
      if cached[:data] && (Time.now - cached[:fetched_at] < ttl)
        cached[:data].to_json
      else
        client = OllamaClient.new
        resp = client.list_models

        if resp.status == 200
          body = resp.body.is_a?(String) ? JSON.parse(resp.body) : resp.body
          models = (body['models'] || []).map do |m|
            {
              id: m['name'],
              object: 'model',
              owned_by: 'ollama',
              created: (Time.parse(m['modified_at']).to_i rescue nil),
              smart_proxy: {
                size: m['size'],
                digest: m['digest'],
                details: m['details']
              }.compact
            }.compact
          end

          payload = { object: 'list', data: models }
          settings.models_cache = { fetched_at: Time.now, data: payload }
          payload.to_json
        else
          $logger.warn({ event: 'ollama_models_error', session_id: @session_id, status: resp.status, body: resp.body })
          fallback = cached[:data] || { object: 'list', data: [] }
          fallback.to_json
        end
      end
    rescue StandardError => e
      $logger.error({ event: 'models_endpoint_error', session_id: @session_id, error: e.message })
      fallback = settings.models_cache[:data] || { object: 'list', data: [] }
      fallback.to_json
    end
  end

  # OpenAI-compatible chat completions endpoint.
  # This is the primary endpoint used by the Rails app (via `ai-agents` / RubyLLM).
  post '/v1/chat/completions' do
    request.body.rewind if request.body.respond_to?(:rewind)
    body_content = request.body.read
    request_payload = JSON.parse(body_content)

    anonymized_payload = Anonymizer.anonymize(request_payload)

    $logger.info({
      event: 'chat_completions_request_received',
      session_id: @session_id,
      payload: anonymized_payload
    })

    model = anonymized_payload['model'].to_s

    # Ollama model ids in this repo look like `llama3.1:8b`.
    # Route to Ollama unless it clearly looks like a Grok model.
    use_grok = model.start_with?('grok') && (ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])

    response = if use_grok
      client = GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])
      client.chat_completions(anonymized_payload)
    else
      client = OllamaClient.new
      client.chat(anonymized_payload)
    end

    $logger.info({
      event: 'chat_completions_response_received',
      session_id: @session_id,
      status: response.status,
      body: response.body
    })

    status response.status

    raw_body = response.body
    parsed = raw_body.is_a?(String) ? (JSON.parse(raw_body) rescue nil) : raw_body

    # If upstream already returned OpenAI-compatible JSON, pass it through.
    if parsed.is_a?(Hash) && parsed.key?('choices')
      parsed.to_json
    # Map Ollama `/api/chat` response into OpenAI `/v1/chat/completions` format.
    # Ollama commonly returns: {"model":"...","created_at":"...","message":{"role":"assistant","content":"..."},"done":true}
    elsif parsed.is_a?(Hash) && parsed['message'].is_a?(Hash)
      msg = parsed['message']

      created = begin
        Time.parse(parsed['created_at'].to_s).to_i
      rescue StandardError
        Time.now.to_i
      end

      {
        id: "chatcmpl-#{SecureRandom.hex(8)}",
        object: 'chat.completion',
        created: created,
        model: model.empty? ? parsed['model'] : model,
        choices: [
          {
            index: 0,
            finish_reason: 'stop',
            message: {
              role: msg['role'] || 'assistant',
              content: msg['content']
            }
          }
        ]
      }.to_json
    else
      # Fallback: return a minimal OpenAI-shaped response with stringified body.
      {
        id: "chatcmpl-#{SecureRandom.hex(8)}",
        object: 'chat.completion',
        created: Time.now.to_i,
        model: model,
        choices: [
          {
            index: 0,
            finish_reason: 'stop',
            message: {
              role: 'assistant',
              content: raw_body.to_s
            }
          }
        ]
      }.to_json
    end
  rescue JSON::ParserError => e
    $logger.error({ event: 'chat_completions_json_parse_error', session_id: @session_id, error: e.message })
    status 400
    { error: 'Invalid JSON payload' }.to_json
  rescue StandardError => e
    $logger.error({ event: 'chat_completions_internal_error', session_id: @session_id, error: e.message, backtrace: (e.backtrace || []).first(5) })
    status 500
    { error: e.message }.to_json
  end

  post '/proxy/tools' do
    request.body.rewind if request.body.respond_to?(:rewind)
    body_content = request.body.read
    request_payload = JSON.parse(body_content)
    
    query = request_payload['query']
    num_results = request_payload['num_results'] || 5

    $logger.info({
      event: 'tool_request_received',
      session_id: @session_id,
      query: query
    })

    client = ToolClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'], session_id: @session_id)
    
    web_resp = client.web_search(query, num_results: num_results)
    x_resp = client.x_keyword_search(query, limit: num_results)

    web_results = web_resp.status == 200 ? JSON.parse(web_resp.body) : { error: web_resp.body }
    x_results = x_resp.status == 200 ? JSON.parse(x_resp.body) : { error: x_resp.body }

    confidence = calculate_confidence(web_results, x_results, query)

    # Re-query if confidence is low
    if confidence < 0.5 && request_payload['retry'] != false
      $logger.info({ event: 'low_confidence_retry', session_id: @session_id, confidence: confidence })
      # Simple refinement: append keywords from query? For now just retry once.
      web_resp = client.web_search(query, num_results: num_results + 2)
      web_results = web_resp.status == 200 ? JSON.parse(web_resp.body) : { error: web_resp.body }
      confidence = calculate_confidence(web_results, x_results, query)
    end

    result = {
      confidence: confidence,
      web_results: web_results,
      x_results: x_results,
      session_id: @session_id
    }

    $logger.info({
      event: 'tool_response_sent',
      session_id: @session_id,
      confidence: confidence
    })

    result.to_json
  end

  post '/proxy/generate' do
    request.body.rewind if request.body.respond_to?(:rewind)
    body_content = request.body.read
    request_payload = JSON.parse(body_content)
    
    # Anonymize request
    anonymized_payload = Anonymizer.anonymize(request_payload)
    
    $logger.info({
      event: 'request_received',
      session_id: @session_id,
      payload: anonymized_payload
    })

    if anonymized_payload['model'] == 'ollama'
      client = OllamaClient.new
      response = client.chat(anonymized_payload)
    else
      client = GrokClient.new(api_key: ENV['GROK_API_KEY_SAP'] || ENV['GROK_API_KEY'])
      response = client.chat_completions(anonymized_payload)
    end

    $logger.info({
      event: 'response_received',
      session_id: @session_id,
      status: response.status,
      body: response.body
    })

    status response.status
    response.body.to_json
  rescue JSON::ParserError => e
    $logger.error({ event: 'json_parse_error', session_id: @session_id, error: e.message })
    status 400
    { error: 'Invalid JSON payload' }.to_json
  rescue StandardError => e
    $logger.error({ event: 'internal_error', session_id: @session_id, error: e.message, backtrace: (e.backtrace || []).first(5) })
    status 500
    { error: e.message }.to_json
  end

  private

  def calculate_confidence(web, x, query)
    # Heuristic: 0.5 base if we have any results. 
    # Add 0.1 per result up to 0.4.
    # Add 0.1 if query keywords match titles.
    score = 0.0
    
    web_count = web.is_a?(Hash) && web['results'] ? web['results'].size : 0
    x_count = x.is_a?(Hash) && x['results'] ? x['results'].size : 0
    
    score += 0.3 if web_count > 0
    score += 0.2 if x_count > 0
    
    score += [web_count * 0.05, 0.2].min
    score += [x_count * 0.05, 0.2].min
    
    # Simple keyword match
    keywords = query.downcase.split
    titles = ""
    titles += web['results'].map { |r| r['title'] }.join(" ") if web.is_a?(Hash) && web['results']
    titles += x['results'].map { |r| r['text'] }.join(" ") if x.is_a?(Hash) && x['results']
    
    match_count = keywords.count { |kw| titles.downcase.include?(kw) }
    score += 0.1 if match_count > keywords.size / 2
    
    [score, 1.0].min.round(2)
  end

  def authenticate!
    auth_token = ENV['PROXY_AUTH_TOKEN']
    # If not set, skip auth for local dev? PRD says "Require API key auth"
    return if auth_token.nil? || auth_token.empty?
    
    auth_header = request.env['HTTP_AUTHORIZATION']
    provided_token = auth_header&.gsub(/^Bearer /, '')&.strip
    
    if provided_token != auth_token
      $logger.warn({ event: 'unauthorized_access', provided_token: provided_token })
      halt 401, { error: 'Unauthorized' }.to_json
    end
  end

  run! if app_file == $0
end
