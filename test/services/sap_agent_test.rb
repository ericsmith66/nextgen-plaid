require 'test_helper'

class SapAgentTest < ActiveSupport::TestCase
  setup do
    @payload = { query: "Test PRD query" }
  end

  test "SapAgent.process dispatches to GenerateCommand" do
    # Mocking AiFinancialAdvisor to avoid actual network calls during unit tests
    AiFinancialAdvisor.stub :ask, "Mocked PRD response" do
      result = SapAgent.process('generate', @payload)
      assert_equal "Mocked PRD response", result[:response]
    end
  end

  test "SapAgent.process raises error for unknown query type" do
    assert_raises(RuntimeError) do
      SapAgent.process('unknown', @payload)
    end
  end

  test "GenerateCommand generates correct prompt" do
    command = SapAgent::GenerateCommand.new(@payload)
    prompt = command.send(:prompt)
    assert_match /You are the SAP Agent/, prompt
    assert_match /Test PRD query/, prompt
  end

  test "QaCommand generates correct prompt" do
    command = SapAgent::QaCommand.new({ question: "How to fix this?", context: "Some code" })
    prompt = command.send(:prompt)
    assert_match /Answer the following question/, prompt
    assert_match /How to fix this?/, prompt
    assert_match /Some code/, prompt
  end

  test "DebugCommand generates correct prompt" do
    command = SapAgent::DebugCommand.new({ issue: "Crash", logs: "Error log" })
    prompt = command.send(:prompt)
    assert_match /Analyze the following logs/, prompt
    assert_match /Crash/, prompt
    assert_match /Error log/, prompt
  end
end
