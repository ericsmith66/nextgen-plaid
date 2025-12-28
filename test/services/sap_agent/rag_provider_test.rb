require 'test_helper'

class SapAgentRagProviderTest < ActiveSupport::TestCase
  setup do
    @user = User.first || User.create!(email: "sap_test@example.com", password: "password")
    @snapshot = Snapshot.create!(user: @user, data: { 
      accounts: [
        { name: "Checking", balance: 1234.56, mask: "1111" },
        { name: "Savings", balance: 10000, mask: "2222" }
      ],
      user_info: { email: "sap_test@example.com" }
    })
  end

  test "build_prefix selects correct docs based on query type" do
    # Create mock docs for testing
    File.write(Rails.root.join('PRODUCT_REQUIREMENTS.md'), "Product Requirements")
    File.write(Rails.root.join('0_AI_THINKING_CONTEXT.md'), "AI Thinking Context")
    
    begin
      prefix = SapAgent::RagProvider.build_prefix('generate')
      assert_match(/File: PRODUCT_REQUIREMENTS.md/, prefix)
      assert_match(/File: 0_AI_THINKING_CONTEXT.md/, prefix)
    ensure
      File.delete(Rails.root.join('PRODUCT_REQUIREMENTS.md'))
      File.delete(Rails.root.join('0_AI_THINKING_CONTEXT.md'))
    end
  end

  test "build_prefix includes and anonymizes user snapshot" do
    prefix = SapAgent::RagProvider.build_prefix('generate', @user.id)
    assert_match(/USER DATA SNAPSHOT/, prefix)
    assert_match(/\[REDACTED\]/, prefix) # balance and mask should be redacted
    assert_no_match(/1234.56/, prefix)
    assert_no_match(/1111/, prefix)
  end

  test "build_prefix handles missing user gracefully" do
    prefix = SapAgent::RagProvider.build_prefix('generate', 999999)
    assert_match(/No snapshot found for user 999999/, prefix)
  end

  test "truncation logic works" do
    # Mock MAX_CONTEXT_CHARS to a small value for testing
    SapAgent::RagProvider.send(:remove_const, :MAX_CONTEXT_CHARS)
    SapAgent::RagProvider.const_set(:MAX_CONTEXT_CHARS, 50)
    
    prefix = SapAgent::RagProvider.build_prefix('default')
    assert prefix.length <= 100 # Plus some for the truncation message
    assert_match(/\[TRUNCATED due to length limits\]/, prefix)
    
    # Reset it back (cleanup)
    SapAgent::RagProvider.send(:remove_const, :MAX_CONTEXT_CHARS)
    SapAgent::RagProvider.const_set(:MAX_CONTEXT_CHARS, 4000)
  end
end
