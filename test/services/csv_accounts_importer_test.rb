require "test_helper"

class CsvAccountsImporterTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "csv_test@example.com", password: "password123")
    @csv_path = Rails.root.join("test/fixtures/files/accounts.csv").to_s
  end

  def teardown
    # Clean up any created records
    Account.where(source: :csv).destroy_all
    PlaidItem.where(institution_id: "jpmc").destroy_all
  end

  test "imports valid accounts from CSV" do
    importer = CsvAccountsImporter.new(@csv_path)

    assert_difference "Account.count", 5 do
      assert_difference "PlaidItem.count", 1 do
        result = importer.call(user: @user)
        assert result, "Import should succeed"
      end
    end

    assert_equal 5, importer.imported_count
    assert_equal 1, importer.skipped_count
  end

  test "creates mock PlaidItem for jpmc" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    plaid_item = PlaidItem.find_by(user: @user, institution_id: "jpmc")
    assert_not_nil plaid_item
    assert_equal "JPMorgan Chase", plaid_item.institution_name
    assert_equal "good", plaid_item.status
    assert_nil plaid_item.access_token
  end

  test "reuses existing PlaidItem for jpmc" do
    existing_item = PlaidItem.create!(
      user: @user,
      item_id: "existing_jpmc",
      institution_id: "jpmc",
      institution_name: "JPMorgan Chase",
      status: "good"
    )

    importer = CsvAccountsImporter.new(@csv_path)

    assert_no_difference "PlaidItem.count" do
      importer.call(user: @user)
    end

    # Verify accounts are linked to existing item
    accounts = Account.where(source: :csv, plaid_item: existing_item)
    assert_equal 5, accounts.count
  end

  test "imports account with correct attributes" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    account = Account.find_by(account_id: "1234567008", source: :csv)
    assert_not_nil account
    assert_equal "7008", account.mask
    assert_equal "Smith Family Checking", account.name
    assert_equal "checking", account.type
    assert_equal "Personal Checking", account.subtype
    assert_equal 16581.33, account.current_balance
    assert_nil account.trust_code
    assert_equal "jpmc", account.source_institution
    assert_not_nil account.import_timestamp
  end

  test "imports account with trust_code" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    account = Account.find_by(account_id: "9876543210", source: :csv)
    assert_not_nil account
    assert_equal "SFRT", account.trust_code
    assert_equal "investment", account.type
    assert_equal 125000.00, account.current_balance
  end

  test "skips row with invalid account type" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    account = Account.find_by(account_id: "0000000001", source: :csv)
    assert_nil account

    assert_includes importer.errors.join, "Invalid account type"
  end

  test "imports row with zero balance" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    account = Account.find_by(account_id: "2222223456", source: :csv)
    assert_not_nil account
    assert_equal 0.0, account.current_balance
  end

  test "handles missing file" do
    importer = CsvAccountsImporter.new("/nonexistent/file.csv")
    result = importer.call(user: @user)

    assert_not result
    assert_includes importer.errors.first, "File not found"
  end

  test "handles malformed CSV" do
    malformed_csv = Rails.root.join("tmp/malformed.csv")
    File.write(malformed_csv, "Account Number,Accounts\n\"Unclosed quote")

    importer = CsvAccountsImporter.new(malformed_csv.to_s)
    result = importer.call(user: @user)

    assert_not result
    assert_includes importer.errors.join, "Malformed CSV"

    File.delete(malformed_csv) if File.exist?(malformed_csv)
  end

  test "logs completion message" do
    importer = CsvAccountsImporter.new(@csv_path)

    assert_difference "Account.count", 5 do
      importer.call(user: @user)
    end

    assert_equal 5, importer.imported_count
    assert_equal 1, importer.skipped_count
  end

  test "allows same account_id with different source" do
    # Create a plaid account first
    plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "plaid_item",
      institution_id: "plaid_inst",
      institution_name: "Plaid Bank",
      status: "good"
    )
    Account.create!(
      plaid_item: plaid_item,
      account_id: "1234567008",
      mask: "7008",
      source: :plaid
    )

    # Import CSV with same account_id but source: csv
    importer = CsvAccountsImporter.new(@csv_path)
    result = importer.call(user: @user)

    assert result
    assert_equal 2, Account.where(account_id: "1234567008").count
    assert_equal 1, Account.where(account_id: "1234567008", source: :plaid).count
    assert_equal 1, Account.where(account_id: "1234567008", source: :csv).count
  end

  test "parses balance with currency symbols and commas" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    account = Account.find_by(account_id: "5555556789", source: :csv)
    assert_equal 50000.00, account.current_balance
  end

  test "extracts mask from account number" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    account = Account.find_by(account_id: "1111112345", source: :csv)
    assert_equal "2345", account.mask
  end

  test "maps account types correctly" do
    importer = CsvAccountsImporter.new(@csv_path)
    importer.call(user: @user)

    checking = Account.find_by(account_id: "1234567008", source: :csv)
    assert_equal "checking", checking.type

    investment = Account.find_by(account_id: "9876543210", source: :csv)
    assert_equal "investment", investment.type

    savings = Account.find_by(account_id: "5555556789", source: :csv)
    assert_equal "savings", savings.type
  end
end
