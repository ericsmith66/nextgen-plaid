require "test_helper"

class AccountTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @item = PlaidItem.create!(user: @user, item_id: "item_test", institution_name: "Test Bank", access_token: "tok", status: "good")
    @account = Account.create!(plaid_item: @item, account_id: "acc_test")
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
end
