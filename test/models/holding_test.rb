require "test_helper"

class HoldingTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @item = PlaidItem.create!(user: @user, item_id: "item_test", institution_name: "Test Bank", access_token: "tok", status: "good")
    @account = Account.create!(plaid_item: @item, account_id: "acc_test")
  end

  test "should create holding with valid attributes" do
    holding = Holding.new(
      account: @account,
      security_id: "sec_123",
      symbol: "AAPL",
      name: "Apple Inc.",
      quantity: BigDecimal("5.0"),
      cost_basis: BigDecimal("40.0"),
      market_value: BigDecimal("210.75")
    )
    assert holding.save
  end

  test "should require security_id" do
    holding = Holding.new(account: @account)
    assert_not holding.valid?
    assert_includes holding.errors[:security_id], "can't be blank"
  end

  test "should enforce uniqueness of security_id scoped to account_id" do
    Holding.create!(account: @account, security_id: "sec_dup")
    duplicate = Holding.new(account: @account, security_id: "sec_dup")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:security_id], "has already been taken"
  end

  test "should belong to account" do
    holding = Holding.create!(account: @account, security_id: "sec_assoc")
    assert_equal @account, holding.account
  end

  # Test decimal formatting methods to avoid scientific notation
  test "quantity_s should return fixed decimal notation" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_qty",
      quantity: BigDecimal("0.5e1")  # 5.0 in scientific notation
    )
    assert_equal "5.0", holding.quantity_s
  end

  test "cost_basis_s should return fixed decimal notation" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_cost",
      cost_basis: BigDecimal("0.4e2")  # 40.0 in scientific notation
    )
    assert_equal "40.0", holding.cost_basis_s
  end

  test "market_value_s should return fixed decimal notation" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_market",
      market_value: BigDecimal("0.21075e3")  # 210.75 in scientific notation
    )
    assert_equal "210.75", holding.market_value_s
  end

  test "vested_value_s should return fixed decimal notation" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_vested",
      vested_value: BigDecimal("0.66e2")  # 66.0 in scientific notation
    )
    assert_equal "66.0", holding.vested_value_s
  end

  test "institution_price_s should return fixed decimal notation" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_price",
      institution_price: BigDecimal("0.4215e2")  # 42.15 in scientific notation
    )
    assert_equal "42.15", holding.institution_price_s
  end

  test "formatting methods should handle nil values" do
    holding = Holding.create!(account: @account, security_id: "sec_nil")
    assert_nil holding.quantity_s
    assert_nil holding.cost_basis_s
    assert_nil holding.market_value_s
    assert_nil holding.vested_value_s
    assert_nil holding.institution_price_s
  end

  # Test inspect override to show fixed decimal notation
  test "inspect should display decimals in fixed notation" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_inspect",
      quantity: BigDecimal("0.5e1"),
      cost_basis: BigDecimal("0.4e2"),
      market_value: BigDecimal("0.21075e3")
    )
    
    inspect_output = holding.inspect
    
    # Should contain fixed notation, not scientific
    assert_match(/quantity: 5\.0/, inspect_output)
    assert_match(/cost_basis: 40\.0/, inspect_output)
    assert_match(/market_value: 210\.75/, inspect_output)
    
    # Should not contain scientific notation
    assert_no_match(/0\.5e1/, inspect_output)
    assert_no_match(/0\.4e2/, inspect_output)
    assert_no_match(/0\.21075e3/, inspect_output)
  end

  test "inspect should handle nil decimal values" do
    holding = Holding.create!(account: @account, security_id: "sec_inspect_nil")
    inspect_output = holding.inspect
    
    # Should contain nil for unset decimal fields
    assert_match(/quantity: nil/, inspect_output)
    assert_match(/cost_basis: nil/, inspect_output)
  end
end
