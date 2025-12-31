require 'test_helper'

class SapAgentSmartproxyIntegrationTest < ActiveSupport::TestCase
  def setup
    skip "Set INTEGRATION_TESTS=1 to run" unless ENV['INTEGRATION_TESTS']
    
    # Disable VCR for integration tests to allow real HTTP requests
    # Must be done BEFORE smartproxy_running? check
    VCR.turn_off!
    WebMock.allow_net_connect!
    
    # Now check if SmartProxy is running
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

  test "generate_iteration_output calls real SmartProxy with ollama" do
    output = SapAgent.send(:generate_iteration_output, "Write a one-sentence summary of what a PRD is", 1, "ollama")
    
    assert output.is_a?(String), "Output should be a string"
    assert output.length > 50, "Output should be substantial (got #{output.length} chars)"
    refute_match /Iteration \d+ response using/, output, "Should not be a stub response"
    assert_match /product|requirement|document/i, output, "Should mention PRD-related terms"
  end

  test "generate_iteration_output calls real SmartProxy with grok" do
    output = SapAgent.send(:generate_iteration_output, "Write a one-sentence summary of what a PRD is", 1, "grok-4")
    
    assert output.is_a?(String), "Output should be a string"
    assert output.length > 50, "Output should be substantial (got #{output.length} chars)"
    refute_match /Iteration \d+ response using/, output, "Should not be a stub response"
    assert_match /product|requirement|document/i, output, "Should mention PRD-related terms"
  end

  test "iterate_prompt full flow with real SmartProxy" do
    result = SapAgent.iterate_prompt(
      task: "Write a one-sentence summary of what a PRD is",
      correlation_id: SecureRandom.uuid
    )

    assert result.is_a?(Hash), "Result should be a hash"
    assert_includes %w[completed aborted], result[:status], "Should have valid status"
    assert result[:iterations].is_a?(Array), "Should have iterations array"
    assert result[:iterations].any?, "Should have at least one iteration"
    
    first_iteration = result[:iterations].first
    assert first_iteration[:output].is_a?(String), "Iteration output should be a string"
    assert first_iteration[:output].length > 50, "Iteration output should be substantial"
    refute_match /Iteration \d+ response using/, first_iteration[:output], "Should not be a stub"
  end

  test "adaptive_iterate full flow with real SmartProxy" do
    result = SapAgent.adaptive_iterate(
      task: "Write a one-sentence summary of what a PRD is",
      correlation_id: SecureRandom.uuid
    )

    assert result.is_a?(Hash), "Result should be a hash"
    assert_includes %w[completed aborted], result[:status], "Should have valid status"
    assert result[:iterations].is_a?(Array), "Should have iterations array"
    assert result[:iterations].any?, "Should have at least one iteration"
    
    first_iteration = result[:iterations].first
    assert first_iteration[:output].is_a?(String), "Iteration output should be a string"
    assert first_iteration[:output].length > 50, "Iteration output should be substantial"
    refute_match /Iteration \d+ response using/, first_iteration[:output], "Should not be a stub"
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
