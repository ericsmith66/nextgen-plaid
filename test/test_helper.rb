ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "warden/test/helpers"

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
end

class ActionDispatch::IntegrationTest
  include Warden::Test::Helpers

  def setup
    super
    Warden.test_mode!
  end

  def teardown
    Warden.test_reset!
    super
  end
end
