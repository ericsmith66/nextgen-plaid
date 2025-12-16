require "test_helper"

class HoldingTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @item = PlaidItem.create!(user: @user, item_id: "item_test", institution_name: "Test Bank", access_token: "tok", status: "good")
    @account = Account.create!(plaid_item: @item, account_id: "acc_test", mask: "1234")
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

  test "should enforce uniqueness of security_id scoped to account_id and source" do
    Holding.create!(account: @account, security_id: "sec_dup", symbol: "TEST", quantity: 1, market_value: 100, source: :plaid)
    duplicate = Holding.new(account: @account, security_id: "sec_dup", symbol: "TEST", quantity: 1, market_value: 100, source: :plaid)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:security_id], "has already been taken"
  end

  test "should allow same security_id for different sources" do
    Holding.create!(account: @account, security_id: "sec_multi", symbol: "TEST", quantity: 1, market_value: 100, source: :plaid)
    csv_holding = Holding.new(account: @account, security_id: "sec_multi", symbol: "TEST", quantity: 2, market_value: 200, source: :csv)
    assert csv_holding.valid?
    assert csv_holding.save
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

  # PRD 9: Test securities metadata fields
  test "should accept securities metadata fields" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_meta",
      symbol: "AAPL",
      name: "Apple Inc.",
      isin: "US0378331005",
      cusip: "037833100",
      sector: "Technology",
      industry: "Consumer Electronics"
    )
    
    assert_equal "US0378331005", holding.isin
    assert_equal "037833100", holding.cusip
    assert_equal "Technology", holding.sector
    assert_equal "Consumer Electronics", holding.industry
  end

  test "securities metadata fields should be nullable" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_nullable",
      symbol: "CUSTOM"
    )
    
    assert_nil holding.isin
    assert_nil holding.cusip
    assert_nil holding.sector
    assert_nil holding.industry
  end

  test "should handle Unknown sector" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_unknown",
      sector: "Unknown"
    )
    
    assert_equal "Unknown", holding.sector
  end

  # CSV-2: Test source enum
  test "should have source enum with plaid and csv values" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_enum",
      symbol: "TEST",
      quantity: 1,
      market_value: 100
    )
    
    assert_equal "plaid", holding.source
    
    holding.source = :csv
    assert holding.save
    assert_equal "csv", holding.source
  end

  test "source should default to plaid" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_default",
      symbol: "TEST",
      quantity: 1,
      market_value: 100
    )
    
    assert_equal "plaid", holding.source
  end

  # CSV-2: Test CSV-specific fields
  test "should accept CSV import fields" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_csv",
      symbol: "NVDA",
      name: "NVIDIA CORP",
      quantity: 100,
      market_value: 20249.00,
      unrealized_gl: 5710.00,
      acquisition_date: Date.parse("2024-01-15"),
      ytm: 2.50,
      maturity_date: Date.parse("2028-06-01"),
      disclaimers: { cost: "X", quantity: "Y" },
      source: :csv,
      source_institution: "jpmc",
      import_timestamp: Time.current
    )
    
    assert_equal 5710.00, holding.unrealized_gl.to_f
    assert_equal Date.parse("2024-01-15"), holding.acquisition_date
    assert_equal 2.50, holding.ytm.to_f
    assert_equal Date.parse("2028-06-01"), holding.maturity_date
    assert_equal({ "cost" => "X", "quantity" => "Y" }, holding.disclaimers)
    assert_equal "csv", holding.source
    assert_equal "jpmc", holding.source_institution
    assert_not_nil holding.import_timestamp
  end

  test "CSV fields should be nullable" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_nullable_csv",
      symbol: "TEST",
      quantity: 1,
      market_value: 100,
      source: :csv
    )
    
    assert_nil holding.unrealized_gl
    assert_nil holding.acquisition_date
    assert_nil holding.ytm
    assert_nil holding.maturity_date
    assert_nil holding.disclaimers
    assert_nil holding.source_institution
    assert_nil holding.import_timestamp
  end

  test "disclaimers should parse JSON correctly" do
    holding = Holding.create!(
      account: @account,
      security_id: "sec_json",
      symbol: "TEST",
      quantity: 1,
      market_value: 100,
      disclaimers: { cost: "Estimated", quantity: "Approximate" }
    )
    
    assert_instance_of Hash, holding.disclaimers
    assert_equal "Estimated", holding.disclaimers["cost"]
    assert_equal "Approximate", holding.disclaimers["quantity"]
  end

  # CSV-2: Test validations for CSV imports
  test "should require symbol for CSV holdings" do
    holding = Holding.new(
      account: @account,
      security_id: "sec_no_symbol",
      quantity: 1,
      market_value: 100,
      source: :csv
    )
    
    assert_not holding.valid?
    assert_includes holding.errors[:symbol], "can't be blank"
  end

  test "should require quantity for CSV holdings" do
    holding = Holding.new(
      account: @account,
      security_id: "sec_no_qty",
      symbol: "TEST",
      market_value: 100,
      source: :csv
    )
    
    assert_not holding.valid?
    assert_includes holding.errors[:quantity], "can't be blank"
  end

  test "should require market_value for CSV holdings" do
    holding = Holding.new(
      account: @account,
      security_id: "sec_no_value",
      symbol: "TEST",
      quantity: 1,
      source: :csv
    )
    
    assert_not holding.valid?
    assert_includes holding.errors[:market_value], "can't be blank"
  end
end
