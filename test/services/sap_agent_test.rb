require 'test_helper'

class SapAgentTest < ActiveSupport::TestCase
  setup do
    @payload = { query: "Test PRD query" }
  end

  test "SapAgent.process incorporates RAG context" do
    user = User.first || User.create!(email: "sap_test_integration@example.com", password: "password")
    Snapshot.create!(user: user, data: { status: "active" })
    
    AiFinancialAdvisor.stub :ask, ->(prompt) { prompt } do
      result = SapAgent.process('generate', @payload.merge(user_id: user.id))
      assert_match /\[CONTEXT START\]/, result[:response]
      assert_match /USER DATA SNAPSHOT/, result[:response]
      assert_match /"status":"active"/, result[:response]
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
    # Prompt comes from `config/agent_prompts/sap_system.md` plus the user request.
    assert_match(/System Prompt/i, prompt)
    assert_match(/User Request:\s+Test PRD query/, prompt)
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
