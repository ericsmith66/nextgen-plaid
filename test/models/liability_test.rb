require "test_helper"

class LiabilityTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @item = PlaidItem.create!(user: @user, item_id: "item_test", institution_name: "Test Bank", access_token: "tok", status: "good")
    @account = Account.create!(plaid_item: @item, account_id: "acc_test")
  end

  test "should create liability with valid attributes" do
    liability = Liability.new(
      account: @account,
      liability_id: "liab_123",
      liability_type: "CREDIT_CARD",
      current_balance: 1500.00,
      min_payment_due: 50.00,
      apr_percentage: 18.99
    )
    assert liability.save
  end

  test "should require liability_id" do
    liability = Liability.new(account: @account)
    assert_not liability.valid?
    assert_includes liability.errors[:liability_id], "can't be blank"
  end

  test "should enforce uniqueness of liability_id scoped to account_id" do
    Liability.create!(account: @account, liability_id: "liab_dup")
    duplicate = Liability.new(account: @account, liability_id: "liab_dup")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:liability_id], "has already been taken"
  end

  test "should belong to account" do
    liability = Liability.create!(account: @account, liability_id: "liab_assoc")
    assert_equal @account, liability.account
  end
end
