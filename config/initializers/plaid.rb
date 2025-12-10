require "plaid"

config = Plaid::Configuration.new
config.server_index = Plaid::Configuration::Environment[ENV['PLAID_ENV'] || 'sandbox']
config.api_key['PLAID-CLIENT-ID'] = ENV['PLAID_CLIENT_ID']
config.api_key['PLAID-SECRET'] = ENV['PLAID_SECRET']

api_client = Plaid::ApiClient.new(config)
PLAID_CLIENT = Plaid::PlaidApi.new(api_client)

Rails.logger.info "PLAID READY | Env: #{ENV['PLAID_ENV']} | Client-ID: #{ENV['PLAID_CLIENT_ID']&.first(8)}...#{ENV['PLAID_CLIENT_ID']&.last(4)}"
