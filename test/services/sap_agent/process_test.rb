# frozen_string_literal: true

require "test_helper"

class SapAgent::ProcessTest < ActiveSupport::TestCase
  def test_process_returns_structured_output_with_metadata
    decision = Ai::RoutingPolicy::Decision.new(
      model_id: "grok-4",
      use_live_search: true,
      max_loops: 1,
      reason: "test",
      policy_version: Ai::RoutingPolicy::POLICY_VERSION
    )

    captured = {}
    fake_response = {
      "model" => "grok-4",
      "choices" => [ { "message" => { "content" => "Final" } } ],
      "smart_proxy" => {
        "tool_loop" => { "loop_count" => 1, "max_loops" => 1 },
        "tools_used" => [ { "name" => "web_search", "tool_call_id" => "call_1" } ]
      }
    }

    Ai::RoutingPolicy.stub :call, decision do
      AiFinancialAdvisor.stub :chat_completions, lambda { |messages:, model:, request_id:, tools:, max_loops:|
        captured[:messages] = messages
        captured[:model] = model
        captured[:request_id] = request_id
        captured[:tools] = tools
        captured[:max_loops] = max_loops
        fake_response
      } do
        result = SapAgent.process(
          "What is Plaid?",
          research: true,
          request_id: "rid-1",
          max_cost_tier: "low"
        )

        assert_equal "Final", result[:response]
        assert_equal 1, result[:loop_count]
        assert_equal "grok-4", result[:model_used]
        assert_equal [ { "name" => "web_search", "tool_call_id" => "call_1" } ], result[:tools_used]

        assert_equal "grok-4", captured[:model]
        assert_equal "rid-1", captured[:request_id]
        assert_equal 1, captured[:max_loops]
        assert captured[:tools].is_a?(Array)
        assert_equal "system", captured[:messages].first[:role]
      end
    end
  end

  def test_process_high_privacy_disables_tools
    decision = Ai::RoutingPolicy::Decision.new(
      model_id: "ollama",
      use_live_search: false,
      max_loops: 0,
      reason: "privacy",
      policy_version: Ai::RoutingPolicy::POLICY_VERSION
    )

    captured = {}
    fake_response = {
      "model" => "ollama",
      "choices" => [ { "message" => { "content" => "Local answer" } } ],
      "smart_proxy" => { "tool_loop" => { "loop_count" => 0, "max_loops" => 0 }, "tools_used" => [] }
    }

    Ai::RoutingPolicy.stub :call, decision do
      AiFinancialAdvisor.stub :chat_completions, lambda { |messages:, model:, request_id:, tools:, max_loops:|
        captured[:messages] = messages
        captured[:tools] = tools
        captured[:max_loops] = max_loops
        fake_response
      } do
        result = SapAgent.process(
          "Sensitive question",
          research: true,
          privacy_level: "high"
        )

        assert_equal "Local answer", result[:response]
        assert_equal [], result[:tools_used]
        assert_equal 0, result[:loop_count]
        assert_nil captured[:tools]
        assert_equal 0, captured[:max_loops]
        assert_equal "user", captured[:messages].first[:role]
      end
    end
  end
end
