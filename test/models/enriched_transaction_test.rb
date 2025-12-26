require "test_helper"

class EnrichedTransactionTest < ActiveSupport::TestCase
  setup do
    user = User.create!(email: "test@example.com", password: "password123")
    item = PlaidItem.create!(user: user, item_id: "test_item", institution_name: "Test Bank", access_token: "test_token")
    @account = Account.create!(plaid_item: item, account_id: "test_acct_123", name: "Test Account", type: "depository", mask: "0000")
    @transaction = Transaction.create!(
      account: @account,
      transaction_id: "test_txn_123",
      name: "Amazon purchase",
      amount: 25.00,
      date: Date.today
    )
  end

  test "creates enriched transaction with valid data" do
    enriched = EnrichedTransaction.create!(
      source_transaction: @transaction,
      merchant_name: "Amazon",
      logo_url: "https://plaid.com/logo.png",
      website: "https://amazon.com",
      personal_finance_category: "Shopping → Online Retail",
      confidence_level: "HIGH"
    )
    
    assert enriched.persisted?
    assert_equal "Amazon", enriched.merchant_name
    assert_equal "HIGH", enriched.confidence_level
  end

  test "enforces uniqueness of transaction_id" do
    EnrichedTransaction.create!(
      source_transaction: @transaction,
      merchant_name: "Amazon",
      confidence_level: "HIGH"
    )
    
    duplicate = EnrichedTransaction.new(
      source_transaction: @transaction,
      merchant_name: "Amazon",
      confidence_level: "HIGH"
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:transaction_id], "has already been taken"
  end

  test "low_confidence? returns true for LOW confidence" do
    enriched = EnrichedTransaction.new(confidence_level: "LOW")
    assert enriched.low_confidence?
  end

  test "low_confidence? returns true for UNKNOWN confidence" do
    enriched = EnrichedTransaction.new(confidence_level: "UNKNOWN")
    assert enriched.low_confidence?
  end

  test "low_confidence? returns true for nil confidence" do
    enriched = EnrichedTransaction.new(confidence_level: nil)
    assert enriched.low_confidence?
  end

  test "low_confidence? returns false for HIGH confidence" do
    enriched = EnrichedTransaction.new(confidence_level: "HIGH")
    assert_not enriched.low_confidence?
  end

  test "use_enriched_data? returns true when high confidence and merchant present" do
    enriched = EnrichedTransaction.new(
      merchant_name: "Amazon",
      confidence_level: "HIGH"
    )
    assert enriched.use_enriched_data?
  end

  test "use_enriched_data? returns false when low confidence" do
    enriched = EnrichedTransaction.new(
      merchant_name: "Amazon",
      confidence_level: "LOW"
    )
    assert_not enriched.use_enriched_data?
  end

  test "use_enriched_data? returns false when merchant name missing" do
    enriched = EnrichedTransaction.new(
      merchant_name: nil,
      confidence_level: "HIGH"
    )
    assert_not enriched.use_enriched_data?
  end
end
