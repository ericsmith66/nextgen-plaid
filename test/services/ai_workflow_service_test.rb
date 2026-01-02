require "test_helper"

class AiWorkflowServiceTest < ActiveSupport::TestCase
  test "handoff occurs and artifacts are written" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Coordinator assigns ball_with=Coordinator"
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        }
      )

    correlation_id = "cid-123"
    result = AiWorkflowService.run(prompt: "Please assign this task", correlation_id: correlation_id)

    assert_equal "Coordinator", result.context[:ball_with]
    assert_includes result.output.to_s, "Coordinator"

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    assert File.exist?(run_dir.join("run.json")), "expected run.json to exist"
    assert File.exist?(run_dir.join("events.ndjson")), "expected events.ndjson to exist"

    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "agent_handoff" && e["from"] == "SAP" && e["to"] == "Coordinator" },
           "expected an agent_handoff event SAP -> Coordinator"
  end

  test "guardrail rejects empty prompt" do
    assert_raises(AiWorkflowService::GuardrailError) do
      AiWorkflowService.run(prompt: "   ")
    end
  end

  test "resolve_feedback enters awaiting_feedback when no feedback is provided" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Coordinator requests feedback"
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        }
      )

    correlation_id = "cid-feedback-1"
    result = AiWorkflowService.resolve_feedback(prompt: "Please resolve this", correlation_id: correlation_id, feedback: nil)

    assert_equal "awaiting_feedback", result.context[:state]
    assert_equal 1, result.context[:feedback_history].size

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "feedback_requested" }, "expected a feedback_requested event"
  end

  test "resolve_feedback continues and resolves when feedback is provided" do
    url = "http://localhost:3002/v1/chat/completions"

    stub_request(:post, url)
      .to_return(
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-1",
            object: "chat.completion",
            created: 1,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "tool_calls",
                message: {
                  role: "assistant",
                  content: nil,
                  tool_calls: [
                    {
                      id: "call_1",
                      type: "function",
                      function: {
                        name: "handoff_to_coordinator",
                        arguments: "{}"
                      }
                    }
                  ]
                }
              }
            ],
            usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-2",
            object: "chat.completion",
            created: 2,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Coordinator requests feedback"
                }
              }
            ],
            usage: { prompt_tokens: 12, completion_tokens: 6, total_tokens: 18 }
          }.to_json
        },
        {
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            id: "chatcmpl-3",
            object: "chat.completion",
            created: 3,
            model: "llama3.1:70b",
            choices: [
              {
                index: 0,
                finish_reason: "stop",
                message: {
                  role: "assistant",
                  content: "Final resolution: resolved"
                }
              }
            ],
            usage: { prompt_tokens: 14, completion_tokens: 7, total_tokens: 21 }
          }.to_json
        }
      )

    correlation_id = "cid-feedback-2"
    result = AiWorkflowService.resolve_feedback(
      prompt: "Please resolve this",
      feedback: "Here is the missing detail",
      correlation_id: correlation_id
    )

    assert_equal "resolved", result.context[:state]
    assert_equal 1, result.context[:feedback_history].count { |h| h[:feedback].present? }

    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    events = File.read(run_dir.join("events.ndjson")).lines.map { |l| JSON.parse(l) }
    assert events.any? { |e| e["type"] == "resolution_complete" && e["state"] == "resolved" },
           "expected a resolution_complete event"
  end
end
