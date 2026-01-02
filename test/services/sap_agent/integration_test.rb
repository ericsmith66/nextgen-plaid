require 'test_helper'

class SapAgent::IntegrationTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email: "sap_integration@example.com", password: "password")
    
    # Ensure MCP.md exists for tests
    FileUtils.mkdir_p(Rails.root.join('knowledge_base/static_docs'))
    File.write(Rails.root.join('knowledge_base/static_docs/MCP.md'), "Vision: Private Financial Data Sync")
    
    # Ensure sap_system.md exists
    FileUtils.mkdir_p(Rails.root.join('config/agent_prompts'))
    File.write(Rails.root.join('config/agent_prompts/sap_system.md'), "System Prompt\n[CONTEXT_BACKLOG]\n[VISION_SSOT]")
  end

  test "Router routes to Ollama for small tool-less queries" do
    payload = { query: "Short query", user_id: @user.id }
    # Use ClimateControl to set TOKEN_THRESHOLD for predictable test
    ClimateControl.modify TOKEN_THRESHOLD: '1000' do
      model = SapAgent::Router.route(payload)
      assert_equal 'ollama', model
    end
  end

  test "Router delegates to Ai::RoutingPolicy" do
    payload = { query: "Short query", user_id: @user.id }
    decision = Ai::RoutingPolicy::Decision.new(
      model_id: "ollama",
      use_live_search: false,
      max_loops: 0,
      reason: "test",
      policy_version: Ai::RoutingPolicy::POLICY_VERSION
    )

    Ai::RoutingPolicy.stub :call, decision do
      assert_equal "ollama", SapAgent::Router.route(payload)
    end
  end

  test "Router routes to Grok for complex queries" do
    payload = { query: "Create a full PRD for transaction enrichment", user_id: @user.id }
    model = SapAgent::Router.route(payload)
    assert_equal 'grok-4', model
  end

  test "Router routes to Grok when research is requested" do
    payload = { query: "Small query", research: true, user_id: @user.id }
    model = SapAgent::Router.route(payload)
    assert_equal 'grok-4', model
  end

  test "ArtifactCommand uses research when requested" do
    payload = { query: "Research Plaid", research: true, user_id: @user.id, strategy: :prd }
    command = SapAgent::ArtifactCommand.new(payload)
    
    # We must also mock store! to avoid writing files during tests
    SapAgent::PrdStrategy.stub :store!, true do
      VCR.use_cassette('sap_research_flow') do
        # Mock the call_proxy method to avoid full AI run
        command.stub(:call_proxy, "#### Overview\nPRD with research\n#### Acceptance Criteria\n- AC1\n- AC2\n- AC3\n- AC4\n- AC5\n#### Architectural Context\nTest\n#### Test Cases\nTest") do
          result = command.execute
          assert_not_nil payload[:research_results]
          assert_match /PRD with research/, result[:content]
        end
      end
    end
  end
end
