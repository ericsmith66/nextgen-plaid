require "test_helper"

class AccountTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @item = PlaidItem.create!(user: @user, item_id: "item_test", institution_name: "Test Bank", access_token: "tok", status: "good")
    @account = Account.create!(plaid_item: @item, account_id: "acc_test", mask: "0000")
  end

  # PRD 9: Test diversification_risk? method
  test "diversification_risk? should return false for empty account" do
    assert_not @account.diversification_risk?
  end

  test "diversification_risk? should return false when no sector exceeds 30%" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology", market_value: 250)
    Holding.create!(account: @account, security_id: "sec2", sector: "Healthcare", market_value: 250)
    Holding.create!(account: @account, security_id: "sec3", sector: "Finance", market_value: 250)
    Holding.create!(account: @account, security_id: "sec4", sector: "Energy", market_value: 250)
    
    assert_not @account.diversification_risk?
  end

  test "diversification_risk? should return true when a sector exceeds 30%" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology", market_value: 350)
    Holding.create!(account: @account, security_id: "sec2", sector: "Healthcare", market_value: 100)
    Holding.create!(account: @account, security_id: "sec3", sector: "Finance", market_value: 100)
    
    assert @account.diversification_risk?
  end

  test "diversification_risk? should return true when a sector equals 31%" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology", market_value: 310)
    Holding.create!(account: @account, security_id: "sec2", sector: "Healthcare", market_value: 690)
    
    assert @account.diversification_risk?
  end

  test "diversification_risk? should handle zero market values" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology", market_value: 0)
    
    assert_not @account.diversification_risk?
  end

  # PRD 9: Test sector_concentrations method
  test "sector_concentrations should return empty hash for empty account" do
    assert_equal({}, @account.sector_concentrations)
  end

  test "sector_concentrations should calculate percentages correctly" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology", market_value: 500)
    Holding.create!(account: @account, security_id: "sec2", sector: "Healthcare", market_value: 300)
    Holding.create!(account: @account, security_id: "sec3", sector: "Finance", market_value: 200)
    
    concentrations = @account.sector_concentrations
    
    assert_equal 50.0, concentrations["Technology"]
    assert_equal 30.0, concentrations["Healthcare"]
    assert_equal 20.0, concentrations["Finance"]
  end

  test "sector_concentrations should group holdings by sector" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology", market_value: 200)
    Holding.create!(account: @account, security_id: "sec2", sector: "Technology", market_value: 300)
    Holding.create!(account: @account, security_id: "sec3", sector: "Healthcare", market_value: 500)
    
    concentrations = @account.sector_concentrations
    
    assert_equal 50.0, concentrations["Technology"]
    assert_equal 50.0, concentrations["Healthcare"]
  end

  # PRD 9: Test HNW nonprofit hooks
  test "has_nonprofit_holdings? should return false for empty account" do
    assert_not @account.has_nonprofit_holdings?
  end

  test "has_nonprofit_holdings? should return false when no nonprofit sector" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology")
    Holding.create!(account: @account, security_id: "sec2", sector: "Healthcare")
    
    assert_not @account.has_nonprofit_holdings?
  end

  test "has_nonprofit_holdings? should return true for Non-Profit sector" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Non-Profit")
    
    assert @account.has_nonprofit_holdings?
  end

  test "has_nonprofit_holdings? should return true for nonprofit sector (lowercase)" do
    Holding.create!(account: @account, security_id: "sec1", sector: "nonprofit")
    
    assert @account.has_nonprofit_holdings?
  end

  test "has_nonprofit_holdings? should handle mixed case variations" do
    Holding.create!(account: @account, security_id: "sec1", sector: "NonProfit Services")
    
    assert @account.has_nonprofit_holdings?
  end

  test "nonprofit_holdings should return empty array for account without nonprofits" do
    Holding.create!(account: @account, security_id: "sec1", sector: "Technology")
    
    assert_equal [], @account.nonprofit_holdings
  end

  test "nonprofit_holdings should return only nonprofit holdings" do
    h1 = Holding.create!(account: @account, security_id: "sec1", sector: "Non-Profit")
    h2 = Holding.create!(account: @account, security_id: "sec2", sector: "Technology")
    h3 = Holding.create!(account: @account, security_id: "sec3", sector: "nonprofit")
    
    nonprofit_results = @account.nonprofit_holdings
    
    assert_equal 2, nonprofit_results.size
    assert_includes nonprofit_results, h1
    assert_includes nonprofit_results, h3
    assert_not_includes nonprofit_results, h2
  end

  # PRD 12: Test liability HNW hooks
  test "overdue_payment? should return false when is_overdue is false" do
    @account.update!(is_overdue: false)
    assert_not @account.overdue_payment?
  end

  test "overdue_payment? should return true when is_overdue is true" do
    @account.update!(is_overdue: true)
    assert @account.overdue_payment?
  end

  test "overdue_payment? should return false when is_overdue is nil" do
    @account.update!(is_overdue: nil)
    assert_not @account.overdue_payment?
  end

  test "high_debt_risk? should return false when debt_risk_flag is false" do
    @account.update!(debt_risk_flag: false)
    assert_not @account.high_debt_risk?
  end

  test "high_debt_risk? should return true when debt_risk_flag is true" do
    @account.update!(debt_risk_flag: true)
    assert @account.high_debt_risk?
  end

  test "high_debt_risk? should return false when debt_risk_flag is nil" do
    @account.update!(debt_risk_flag: nil)
    assert_not @account.high_debt_risk?
  end

  test "liability_summary should return nil when no liability data" do
    assert_nil @account.liability_summary
  end

  test "liability_summary should return hash when apr_percentage present" do
    @account.update!(
      apr_percentage: 19.99,
      min_payment_amount: 50.00,
      next_payment_due_date: Date.parse("2025-01-15"),
      is_overdue: false,
      debt_risk_flag: false
    )
    
    summary = @account.liability_summary
    
    assert_not_nil summary
    assert_equal 19.99, summary[:apr_percentage]
    assert_equal 50.00, summary[:min_payment_amount]
    assert_equal Date.parse("2025-01-15"), summary[:next_payment_due_date]
    assert_equal false, summary[:is_overdue]
    assert_equal false, summary[:debt_risk_flag]
  end

  test "liability_summary should return hash when min_payment_amount present" do
    @account.update!(min_payment_amount: 100.00)
    
    summary = @account.liability_summary
    
    assert_not_nil summary
    assert_equal 100.00, summary[:min_payment_amount]
  end

  test "liability_summary should handle high risk debt" do
    @account.update!(
      apr_percentage: 24.99,
      is_overdue: true,
      debt_risk_flag: true
    )
    
    summary = @account.liability_summary
    
    assert_not_nil summary
    assert_equal 24.99, summary[:apr_percentage]
    assert_equal true, summary[:is_overdue]
    assert_equal true, summary[:debt_risk_flag]
  end

  # CSV-3: Test source enum
  test "source enum should default to plaid" do
    account = Account.create!(plaid_item: @item, account_id: "acc_enum_test", mask: "1234")
    assert_equal "plaid", account.source
    assert account.plaid?
  end

  test "source enum should accept csv value" do
    account = Account.create!(plaid_item: @item, account_id: "acc_csv_test", mask: "5678", source: :csv)
    assert_equal "csv", account.source
    assert account.csv?
  end

  test "should allow trust_code field" do
    account = Account.create!(plaid_item: @item, account_id: "acc_trust_test", mask: "9012", trust_code: "SFRT")
    assert_equal "SFRT", account.trust_code
  end

  test "should allow source_institution field" do
    account = Account.create!(plaid_item: @item, account_id: "acc_inst_test", mask: "3456", source_institution: "jpmc")
    assert_equal "jpmc", account.source_institution
  end

  test "should allow import_timestamp field" do
    timestamp = Time.current
    account = Account.create!(plaid_item: @item, account_id: "acc_time_test", mask: "7890", import_timestamp: timestamp)
    assert_equal timestamp.to_i, account.import_timestamp.to_i
  end

  test "should validate presence of mask" do
    account = Account.new(plaid_item: @item, account_id: "acc_no_mask")
    assert_not account.valid?
    assert_includes account.errors[:mask], "can't be blank"
  end

  test "should enforce uniqueness of account_id scoped to plaid_item_id and source" do
    Account.create!(plaid_item: @item, account_id: "acc_unique", mask: "1111", source: :plaid)
    # Same account_id with different source should be allowed
    account_csv = Account.new(plaid_item: @item, account_id: "acc_unique", mask: "1111", source: :csv)
    assert account_csv.valid?

    # Same account_id with same source should not be allowed
    account_duplicate = Account.new(plaid_item: @item, account_id: "acc_unique", mask: "1111", source: :plaid)
    assert_not account_duplicate.valid?
    assert_includes account_duplicate.errors[:account_id], "has already been taken"
  end
end
