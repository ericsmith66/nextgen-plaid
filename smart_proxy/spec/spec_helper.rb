require 'rack/test'
require 'webmock/rspec'
require 'vcr'
require_relative '../app'

RSpec.configure do |config|
  config.include Rack::Test::Methods

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data('<GROK_API_KEY>') { ENV['GROK_API_KEY'] }
  config.filter_sensitive_data('<PROXY_AUTH_TOKEN>') { ENV['PROXY_AUTH_TOKEN'] }
end
