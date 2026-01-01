ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "warden/test/helpers"
require "webmock/minitest"
require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.filter_sensitive_data('<GROK_API_KEY>') { ENV['GROK_API_KEY'] }
  config.filter_sensitive_data('<GROK_API_KEY_SAP>') { ENV['GROK_API_KEY_SAP'] }
end

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all if File.directory?(File.join(__dir__, 'fixtures'))

  def with_stubbed_plaid_client(stubs)
    original = Rails.application.config.x.plaid_client
    stub = Minitest::Mock.new
    stubs.each do |method_name, return_value|
      stub.expect(method_name, return_value, [Object])
    end
    Rails.application.config.x.plaid_client = stub
    yield
  ensure
    Rails.application.config.x.plaid_client = original
  end

  def with_stubbed_plaid_client_error(method_name, error)
    original = Rails.application.config.x.plaid_client
    stub_client = Object.new
    stub_client.define_singleton_method(method_name) do |*args|
      raise error
    end
    Rails.application.config.x.plaid_client = stub_client
    yield
  ensure
    Rails.application.config.x.plaid_client = original
  end
end

class ActionDispatch::IntegrationTest
  include Warden::Test::Helpers
  include Devise::Test::IntegrationHelpers

  def setup
    super
    Warden.test_mode!
  end

  def teardown
    Warden.test_reset!
    super
  end
end
