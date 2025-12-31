require "test_helper"

class SapPrdCreateUiIntegrationTest < ActiveSupport::TestCase
  def setup
    skip "Set INTEGRATION_TESTS=1 to run" unless ENV["INTEGRATION_TESTS"]

    # Disable VCR for integration tests to allow real HTTP requests
    VCR.turn_off!
    WebMock.allow_net_connect!

    # Check if SmartProxy is running
    unless smartproxy_running?
      VCR.turn_on!
      WebMock.disable_net_connect!(allow_localhost: false)
      skip "SmartProxy not running on port 3002"
    end
  end

  def teardown
    # Re-enable VCR after each test
    VCR.turn_on!
    WebMock.disable_net_connect!(allow_localhost: false)
  end

  test "PRD create flow - iterate_prompt with live proxy for PRD task" do
    # Mimic what the UI "Start Adaptive Iterate" button triggers
    # The controller calls SapAgent.iterate_prompt with the task
    task = "I need a PRD to track the implementation of a simple webhook receiver"
    correlation_id = SecureRandom.uuid

    result = SapAgent.iterate_prompt(
      task: task,
      branch: "test/prd-create-integration",
      correlation_id: correlation_id
    )

    # Verify the result structure
    assert result.is_a?(Hash), "Result should be a hash"
    assert_includes %w[completed aborted], result[:status], "Should have valid status"
    assert result[:iterations].is_a?(Array), "Should have iterations array"
    assert result[:iterations].any?, "Should have at least one iteration"

    # Verify iterations contain real content (not stubs)
    first_iteration = result[:iterations].first
    assert first_iteration[:output].is_a?(String), "Iteration output should be a string"
    assert first_iteration[:output].length > 50, "Iteration output should be substantial (got #{first_iteration[:output].length} chars)"
    refute_match /Iteration \d+ response using/, first_iteration[:output], "Should not be a stub response"

    # Verify PRD-related content
    full_output = result[:iterations].map { |i| i[:output] }.join(" ")
    assert_match /product|requirement|document|prd|webhook/i, full_output, "Output should mention PRD or webhook-related terms"
  end

  test "PRD create flow - iterate_prompt with complex PRD task" do
    # Test with a more complex PRD creation task
    task = "Create a PRD for a user login feature with password reset"
    correlation_id = SecureRandom.uuid

    result = SapAgent.iterate_prompt(
      task: task,
      correlation_id: correlation_id
    )

    assert result.is_a?(Hash), "Result should be a hash"
    assert_includes %w[completed aborted error], result[:status], "Should have valid status"
    assert result[:iterations].is_a?(Array), "Should have iterations array"
    assert result[:iterations].any?, "Should have at least one iteration"

    # Verify content is substantial (allow for API errors)
    first_iteration = result[:iterations].first
    assert first_iteration[:output].is_a?(String), "Iteration output should be a string"
    assert first_iteration[:output].length > 20, "Iteration output should have some content"
  end

  test "PRD create flow - iterate_prompt handles short simple task" do
    # Test with a minimal task to ensure it doesn't fail
    task = "Write a one-paragraph PRD for a contact form"
    correlation_id = SecureRandom.uuid

    result = SapAgent.iterate_prompt(
      task: task,
      correlation_id: correlation_id
    )

    assert result.is_a?(Hash), "Result should be a hash"
    assert_includes %w[completed aborted], result[:status], "Should have valid status"
    assert result[:iterations].is_a?(Array), "Should have iterations array"
    assert result[:iterations].any?, "Should have at least one iteration"

    first_iteration = result[:iterations].first
    assert first_iteration[:output].is_a?(String), "Iteration output should be a string"
    assert first_iteration[:output].length > 20, "Iteration output should have some content"
  end

  private

  def smartproxy_running?
    port = ENV['SMART_PROXY_PORT'] || '3002'
    uri = URI("http://localhost:#{port}/health")
    response = Net::HTTP.get_response(uri)
    response.code == '200'
  rescue Errno::ECONNREFUSED, SocketError
    false
  end
end
