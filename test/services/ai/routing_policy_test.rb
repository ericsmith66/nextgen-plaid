# frozen_string_literal: true

require "test_helper"

class AiRoutingPolicyTest < ActiveSupport::TestCase
  def test_routes_simple_prompt_to_ollama_without_live_search
    decision = Ai::RoutingPolicy.call(prompt: "Hello")
    assert_equal "ollama", decision.model_id
    assert_equal false, decision.use_live_search
    assert_equal 0, decision.max_loops
    assert decision.reason.present?
    assert_equal Ai::RoutingPolicy::POLICY_VERSION, decision.policy_version
  end

  def test_routes_complex_prd_prompt_to_grok
    decision = Ai::RoutingPolicy.call(prompt: "# PRD\n## Requirements\n- Do X")
    assert_equal "grok-4", decision.model_id
    assert_equal false, decision.use_live_search
  end

  def test_research_requested_enables_live_search_and_uses_grok
    decision = Ai::RoutingPolicy.call(prompt: "Find latest info", research_requested: true)
    assert_equal "grok-4", decision.model_id
    assert_equal true, decision.use_live_search
    assert_nil decision.max_loops
  end

  def test_high_privacy_forces_ollama_and_disables_live_search
    decision = Ai::RoutingPolicy.call(
      prompt: "PRD with research",
      research_requested: true,
      privacy_level: "high"
    )

    assert_equal "ollama", decision.model_id
    assert_equal false, decision.use_live_search
    assert_equal 0, decision.max_loops
  end

  def test_max_cost_tier_low_prefers_ollama
    decision = Ai::RoutingPolicy.call(prompt: "Hello", max_cost_tier: "low")
    assert_equal "ollama", decision.model_id
    assert_equal false, decision.use_live_search
    assert_equal 0, decision.max_loops
  end

  def test_max_cost_tier_low_allows_live_search_but_limits_loops
    decision = Ai::RoutingPolicy.call(prompt: "Hello", max_cost_tier: "low", research_requested: true)
    assert_equal "grok-4", decision.model_id
    assert_equal true, decision.use_live_search
    assert_equal 1, decision.max_loops
  end
end
