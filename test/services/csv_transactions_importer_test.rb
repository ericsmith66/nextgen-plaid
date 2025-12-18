require "test_helper"

class CsvTransactionsImporterTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "tester@example.com", password: "Password123!")
    @plaid_item = PlaidItem.create!(user_id: @user.id, item_id: "it_1", institution_name: "JPMC Wealth")
    @account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_1",
      mask: "1234",
      name: "Brokerage",
      source: :csv
    )
    @csv_path = Rails.root.join("test", "fixtures", "files", "sample_transactions.csv")
  end

  test "imports valid rows, maps categories, sums amounts, sets pending, and skips invalids" do
    result = CsvTransactionsImporter.call(file_path: @csv_path.to_s, user_id: @user.id)

    assert_equal 3, Transaction.where(account_id: @account.id).count, "expected 3 transactions imported"

    t1 = Transaction.find_by(name: "Dividend Payment")
    assert_not_nil t1
    assert_equal Date.strptime("12/03/2024", "%m/%d/%Y"), t1.date
    assert_equal BigDecimal("105.00"), t1.amount
    assert_equal "dividend_domestic", t1.category
    assert_equal false, t1.pending
    assert_equal "jpmc", t1.source_institution
    assert_equal "csv", t1.source

    t2 = Transaction.find_by(name: "Sell Shares")
    assert_not_nil t2
    assert_equal true, t2.pending, "should be pending due to future settlement date"

    t3 = Transaction.find_by(name: "Unknown Type")
    assert_not_nil t3
    assert_equal "unknown", t3.category

    # Skips
    assert_nil Transaction.find_by(name: "Zero Sum Test"), "zero sum should be skipped"
    assert_nil Transaction.find_by(name: "No Account Row"), "no account should be skipped"
    assert_nil Transaction.find_by(name: "Invalid Date"), "invalid date should be skipped"

    # Idempotent re-import
    before = Transaction.count
    CsvTransactionsImporter.call(file_path: @csv_path.to_s, user_id: @user.id)
    assert_equal before, Transaction.count, "re-import should not create duplicates"

    # dedupe_key present
    assert t1.dedupe_key.present?

    # Result summary contains counts
    assert result.total_rows > 0
  end
end
