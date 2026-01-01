require "test_helper"

# Contract test: ensures our SmartProxy `/v1/chat/completions` shape is compatible with
# `ruby_llm` OpenAI parser as used by `ai-agents`.
class AgentsOpenAiContractTest < ActiveSupport::TestCase
  test "Agents::Runner returns non-empty output for OpenAI-compatible response" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: {
          id: "chatcmpl-contract-1",
          object: "chat.completion",
          created: 1,
          model: "llama3.1:70b",
          choices: [
            {
              index: 0,
              finish_reason: "stop",
              message: {
                role: "assistant",
                content: "Hello from contract test"
              }
            }
          ],
          usage: {
            prompt_tokens: 10,
            completion_tokens: 5,
            total_tokens: 15
          }
        }.to_json
      )

    agent = Agents::Agent.new(name: "TestAgent", instructions: "Reply briefly")
    runner = Agents::Runner.with_agents(agent)

    result = runner.run("Say hello")

    assert result.error.nil?, "expected no error, got #{result.error&.message}"
    assert result.output.to_s.strip.length.positive?, "expected non-empty output"
  end
end
