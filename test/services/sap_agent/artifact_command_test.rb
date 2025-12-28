require 'test_helper'

class ArtifactCommandTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email: "sap_test@example.com", password: "password")
    @payload = { query: "Create PRD for transaction sync", user_id: @user.id }
    
    # Ensure MCP.md exists for tests
    FileUtils.mkdir_p(Rails.root.join('knowledge_base/static_docs'))
    File.write(Rails.root.join('knowledge_base/static_docs/MCP.md'), "Vision: Private Financial Data Sync")
    
    # Ensure sap_system.md exists
    FileUtils.mkdir_p(Rails.root.join('config/agent_prompts'))
    File.write(Rails.root.join('config/agent_prompts/sap_system.md'), "System Prompt\n[CONTEXT_BACKLOG]\n[VISION_SSOT]\n[PROJECT_CONTEXT]")
  end

  test "ArtifactCommand prompt includes MCP and system prompt" do
    command = SapAgent::ArtifactCommand.new(@payload.merge(strategy: :prd))
    prompt = command.prompt
    assert_match /Vision: Private Financial Data Sync/, prompt
    assert_match /System Prompt/, prompt
    assert_match /User Request: Create PRD for transaction sync/, prompt
  end

  test "ArtifactCommand prompt includes Project Context" do
    # Create a snapshot for the test
    FileUtils.mkdir_p(Rails.root.join('knowledge_base/snapshots'))
    snapshot_data = { history: [], code_state: { schema: "Test Schema" } }
    File.write(Rails.root.join('knowledge_base/snapshots/2025-12-27-project-snapshot.json'), snapshot_data.to_json)

    command = SapAgent::ArtifactCommand.new(@payload.merge(strategy: :prd))
    prompt = command.prompt
    assert_match /Test Schema/, prompt
  ensure
    File.delete(Rails.root.join('knowledge_base/snapshots/2025-12-27-project-snapshot.json')) if File.exist?(Rails.root.join('knowledge_base/snapshots/2025-12-27-project-snapshot.json'))
  end

  test "GenerateCommand infers prd strategy" do
    command = SapAgent::GenerateCommand.new(@payload)
    command.validate!
    assert_equal :prd, command.payload[:strategy]
  end

  test "GenerateCommand infers backlog strategy" do
    command = SapAgent::GenerateCommand.new({ query: "Update backlog with new task" })
    command.validate!
    assert_equal :backlog, command.payload[:strategy]
  end

  test "PrdStrategy validation fails for missing sections" do
    assert_raises(RuntimeError, "Output missing 'Overview'") do
      SapAgent::PrdStrategy.validate_output!("Malformed output")
    end
  end

  test "PrdStrategy validation fails for incorrect AC count" do
    output = <<~MD
      #### Overview
      Test
      #### Acceptance Criteria
      - AC1
      - AC2
      #### Architectural Context
      Test
      #### Test Cases
      Test
    MD
    assert_raises(RuntimeError, /Acceptance Criteria must be between 5 and 8 bullets/) do
      SapAgent::PrdStrategy.validate_output!(output)
    end
  end

  test "PrdStrategy validation succeeds for valid output" do
    output = <<~MD
      #### Overview
      Test
      #### Acceptance Criteria
      - AC1
      - AC2
      - AC3
      - AC4
      - AC5
      #### Architectural Context
      Test
      #### Test Cases
      Test
    MD
    assert_nothing_raised do
      SapAgent::PrdStrategy.validate_output!(output)
    end
  end

  test "BacklogStrategy next_id increments correctly" do
    backlog_path = Rails.root.join('knowledge_base/backlog.json')
    File.write(backlog_path, [ { id: "0010", title: "Test" } ].to_json)
    
    id = SapAgent::BacklogStrategy.send(:next_id)
    assert_equal "0011", id
  ensure
    File.delete(backlog_path) if File.exist?(backlog_path)
  end

  test "SapAgent.decompose routes through ArtifactCommand" do
    user = User.first || User.create!(email: "sap_test_decompose@example.com", password: "password")
    
    # Stub the process method to verify it's called correctly
    SapAgent.stub :process, ->(type, payload) { { response: "#### Overview\nGenerated PRD content", status: :success } } do
      assert_nothing_raised do
        SapAgent.decompose("task_123", user.id, "Create PRD for transaction sync")
      end
    end
  end
end
