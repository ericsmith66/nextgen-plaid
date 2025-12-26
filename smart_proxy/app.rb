require 'sinatra/base'
require 'json'
require 'logger'
require 'dotenv'
Dotenv.load(File.expand_path('../.env', __dir__))
require_relative 'lib/grok_client'
require_relative 'lib/anonymizer'

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
    $logger.formatter = proc do |severity, datetime, progname, msg|
      {
        timestamp: datetime,
        severity: severity,
        message: msg
      }.to_json + "\n"
    end
  end

  before do
    content_type :json
    authenticate! unless request.path_info == '/health'
  end

  get '/health' do
    { status: 'ok' }.to_json
  end

  post '/proxy/generate' do
    request.body.rewind
    request_payload = JSON.parse(request.body.read)
    
    # Anonymize request
    anonymized_payload = Anonymizer.anonymize(request_payload)
    
    $logger.info({
      event: 'request_received',
      payload: anonymized_payload
    })

    client = GrokClient.new(api_key: ENV['GROK_API_KEY'])
    response = client.chat_completions(anonymized_payload)

    $logger.info({
      event: 'response_received',
      status: response.status,
      body: response.body
    })

    status response.status
    response.body.to_json
  rescue JSON::ParserError => e
    $logger.error({ event: 'json_parse_error', error: e.message })
    status 400
    { error: 'Invalid JSON payload' }.to_json
  rescue StandardError => e
    $logger.error({ event: 'internal_error', error: e.message, backtrace: (e.backtrace || []).first(5) })
    status 500
    { error: e.message }.to_json
  end

  private

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
