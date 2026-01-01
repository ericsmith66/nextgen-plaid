require "plaid"

# config/initializers/plaid.rb
# In test we always default to sandbox and ignore `PLAID_ENV` (which may be set locally to production).
env_name = if Rails.env.test?
  ENV.fetch("PLAID_ENV_TEST", "sandbox")
else
  ENV.fetch("PLAID_ENV", Rails.env.production? ? "production" : "sandbox")
end
config = Plaid::Configuration.new
config.server_index = Plaid::Configuration::Environment[env_name]

if env_name == "production" && (ENV["PLAID_CLIENT_ID"].blank? || ENV["PLAID_SECRET"].blank?)
  raise "Missing Plaid Production Credentials! Ensure PLAID_CLIENT_ID and PLAID_SECRET are set."
end

config.api_key["PLAID-CLIENT-ID"] = ENV.fetch("PLAID_CLIENT_ID", nil)
config.api_key["PLAID-SECRET"] = ENV.fetch("PLAID_SECRET", nil)

api_client = Plaid::ApiClient.new(config)
client = Plaid::PlaidApi.new(api_client)

Rails.application.config.x.plaid_client = client
# Backwards-compatibility constant (will be removed later)
PLAID_CLIENT = client

Rails.logger.info({ event: "plaid.ready", env: env_name, client_id_present: ENV["PLAID_CLIENT_ID"].present? }.to_json)
