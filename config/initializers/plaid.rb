require "plaid"

config = Plaid::Configuration.new
config.server_index = Plaid::Configuration::Environment[ENV['PLAID_ENV'] || 'sandbox']
config.api_key['PLAID-CLIENT-ID'] = ENV['PLAID_CLIENT_ID']
config.api_key['PLAID-SECRET'] = ENV['PLAID_SECRET']

api_client = Plaid::ApiClient.new(config)
client = Plaid::PlaidApi.new(api_client)

# Preferred access point for app code (easier to stub in tests)
Rails.application.config.x.plaid_client = client

# Backwards-compatibility constant (will be removed later)
PLAID_CLIENT = client

Rails.logger.info "PLAID READY | Env: #{ENV['PLAID_ENV']} | Client-ID: #{ENV['PLAID_CLIENT_ID']&.first(8)}...#{ENV['PLAID_CLIENT_ID']&.last(4)}"
