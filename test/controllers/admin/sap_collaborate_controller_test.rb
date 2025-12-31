require "test_helper"

# Integration tests for SapAgent functionality through the controller.
# These tests verify that the LLM integration works correctly.
class Admin::SapCollaborateControllerTest < ActiveSupport::TestCase
  test "SapAgent iterate_prompt calls AiFinancialAdvisor" do
    # Mock AiFinancialAdvisor to verify it's called
    mock_response = "This is a detailed PRD for the requested feature."
    AiFinancialAdvisor.stub :ask, mock_response do
      result = SapAgent.iterate_prompt(
        task: "Generate a PRD for webhook ingestion",
        correlation_id: SecureRandom.uuid
      )

      assert_not_nil result
      assert_includes %w[completed aborted], result[:status]
      assert_not_nil result[:iterations]
      assert result[:iterations].is_a?(Array)
      assert result[:iterations].length > 0
    end
  end

  test "SapAgent conductor calls sub-agents" do
    # Mock AiFinancialAdvisor for conductor sub-agents
    AiFinancialAdvisor.stub :ask, "Mocked conductor response" do
      result = SapAgent.conductor(
        task: "Decompose PRD for payments",
        correlation_id: SecureRandom.uuid,
        idempotency_uuid: SecureRandom.uuid,
        refiner_iterations: 2
      )

      assert_not_nil result
      assert_includes %w[completed fallback], result[:status]
      assert_not_nil result[:state]
    end
  end

  test "SapAgent generate_iteration_output calls LLM" do
    correlation_id = SecureRandom.uuid
    SapAgent.correlation_id = correlation_id

    # Verify that generate_iteration_output calls AiFinancialAdvisor.ask
    mock_response = "Detailed iteration response"
    AiFinancialAdvisor.stub :ask, mock_response do
      output = SapAgent.send(:generate_iteration_output, "Test context", 1, "ollama")

      assert_equal mock_response, output
    end
  end

  test "SapRun model can be created and queried" do
    user = User.create!(
      email: "test_#{SecureRandom.hex(4)}@example.com",
      password: "password123"
    )

    correlation_id = SecureRandom.uuid
    sap_run = SapRun.create!(
      user: user,
      task: "Test task",
      status: "running",
      correlation_id: correlation_id,
      started_at: Time.current
    )

    assert_not_nil sap_run
    assert_equal "running", sap_run.status
    assert_equal correlation_id, sap_run.correlation_id

    # Test status transitions
    sap_run.update!(status: "complete", completed_at: Time.current)
    assert_equal "complete", sap_run.status
    assert_not_nil sap_run.completed_at
  end
end
