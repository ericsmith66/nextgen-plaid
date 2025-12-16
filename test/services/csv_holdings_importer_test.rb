require "test_helper"

class CsvHoldingsImporterTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com", password: "password123")
    @plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "mock_jpmc_#{@user.id}",
      institution_id: "jpmc",
      institution_name: "JPMorgan Chase",
      status: "good"
    )
    @account = Account.create!(
      plaid_item: @plaid_item,
      account_id: "acc_6002",
      mask: "6002",
      name: "Investment Account",
      type: "investment",
      current_balance: 100000.00,
      source: :csv
    )
    @csv_path = Rails.root.join("test/fixtures/files/holdings_6002.csv").to_s
  end

  test "should import valid holdings from CSV" do
    importer = CsvHoldingsImporter.new(@csv_path)
    
    assert_difference "Holding.count", 5 do
      success = importer.call(user: @user)
      assert success
    end
    
    assert_equal 5, importer.imported_count
    assert_equal 2, importer.skipped_count  # 1 zero quantity + 1 footer
  end

  test "should link holdings to correct account via mask" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    holdings = Holding.where(account: @account, source: :csv)
    assert_equal 5, holdings.count
    
    holdings.each do |holding|
      assert_equal @account.id, holding.account_id
    end
  end

  test "should map CSV fields correctly" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    nvda = Holding.find_by(symbol: "NVDA", source: :csv)
    assert_not_nil nvda
    assert_equal "NVIDIA CORP", nvda.name
    assert_equal "67066G104", nvda.security_id
    assert_equal 100, nvda.quantity.to_i
    assert_equal 20249.00, nvda.market_value.to_f
    assert_equal 14539.00, nvda.cost_basis.to_f
    assert_equal 5710.00, nvda.unrealized_gl.to_f
    assert_equal Date.parse("2024-01-15"), nvda.acquisition_date
    assert_equal "US67066G1040", nvda.isin
    assert_equal "stock", nvda.type
    assert_equal "Core", nvda.subtype
    assert_equal "csv", nvda.source
    assert_equal "jpmc", nvda.source_institution
    assert_not_nil nvda.import_timestamp
  end

  test "should parse datetime fields correctly" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    holding = Holding.find_by(symbol: "NVDA", source: :csv)
    assert_not_nil holding, "NVDA holding should exist"
    assert_not_nil holding.institution_price_as_of, "institution_price_as_of should be set"
    # Check it's approximately the right date (within a day)
    expected = DateTime.strptime("10/31/2025 11:59:59", "%m/%d/%Y %H:%M:%S")
    assert_in_delta expected.to_i, holding.institution_price_as_of.to_i, 86400
  end

  test "should parse decimal values with currency symbols and commas" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    holding = Holding.find_by(symbol: "NVDA", source: :csv)
    assert_equal 20249.00, holding.market_value.to_f
    assert_equal 202.49, holding.institution_price.to_f
  end

  test "should map fixed income type correctly" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    bond = Holding.find_by(security_id: "912828XY1", source: :csv)
    assert_not_nil bond
    assert_equal "fixed_income", bond.type
    assert_equal "Corporate", bond.subtype
    assert_equal 2.50, bond.ytm.to_f
    assert_equal Date.parse("2028-06-01"), bond.maturity_date
  end

  test "should skip rows with zero quantity" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    # TSLA has quantity 0 in fixture
    tsla = Holding.find_by(symbol: "TSLA", source: :csv)
    assert_nil tsla
    
    assert_includes importer.errors.join, "Invalid or zero quantity"
  end

  test "should skip footer rows" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    assert_includes importer.errors.join, "Footer or invalid asset class detected"
  end

  test "should set source to csv for all imported holdings" do
    importer = CsvHoldingsImporter.new(@csv_path)
    importer.call(user: @user)
    
    Holding.where(account: @account).each do |holding|
      assert_equal "csv", holding.source
    end
  end

  test "should fail if file does not exist" do
    importer = CsvHoldingsImporter.new("/nonexistent/file.csv")
    success = importer.call(user: @user)
    
    assert_not success
    assert_includes importer.errors.first, "File not found"
  end

  test "should fail if account not found by mask" do
    # Create CSV with different mask
    csv_path = Rails.root.join("test/fixtures/files/holdings_9999.csv").to_s
    File.write(csv_path, File.read(@csv_path))
    
    importer = CsvHoldingsImporter.new(csv_path)
    success = importer.call(user: @user)
    
    assert_not success
    assert_includes importer.errors.first, "No account found with mask '9999'"
    
    File.delete(csv_path) if File.exist?(csv_path)
  end

  test "should handle malformed CSV" do
    malformed_csv = Rails.root.join("test/fixtures/files/malformed_1234.csv").to_s
    File.write(malformed_csv, "Asset Class,Ticker\n\"Unclosed quote")
    
    importer = CsvHoldingsImporter.new(malformed_csv)
    success = importer.call(user: @user)
    
    assert_not success
    # Could fail at mask extraction or CSV parsing
    assert importer.errors.any?
    
    File.delete(malformed_csv) if File.exist?(malformed_csv)
  end

  test "should update existing holding on re-import" do
    # First import
    importer1 = CsvHoldingsImporter.new(@csv_path)
    importer1.call(user: @user)
    
    original_holding = Holding.find_by(symbol: "NVDA", source: :csv)
    original_timestamp = original_holding.import_timestamp
    
    # Wait a moment to ensure timestamp changes
    sleep 0.1
    
    # Second import (should update, not create new)
    importer2 = CsvHoldingsImporter.new(@csv_path)
    
    assert_no_difference "Holding.count" do
      importer2.call(user: @user)
    end
    
    updated_holding = Holding.find_by(symbol: "NVDA", source: :csv)
    assert updated_holding.import_timestamp > original_timestamp
  end

  test "should allow same security_id from different sources" do
    # Create a Plaid holding with same CUSIP
    Holding.create!(
      account: @account,
      security_id: "67066G104",
      symbol: "NVDA",
      quantity: 50,
      market_value: 10000,
      source: :plaid
    )
    
    # Import CSV with same CUSIP
    importer = CsvHoldingsImporter.new(@csv_path)
    
    assert_difference "Holding.count", 5 do
      success = importer.call(user: @user)
      assert success
    end
    
    # Should have both Plaid and CSV holdings
    nvda_holdings = Holding.where(security_id: "67066G104", account: @account)
    assert_equal 2, nvda_holdings.count
    assert_equal ["csv", "plaid"], nvda_holdings.pluck(:source).sort
  end

  test "should log import completion" do
    importer = CsvHoldingsImporter.new(@csv_path)
    
    assert_difference "Holding.count", 5 do
      importer.call(user: @user)
    end
    
    assert_equal 5, importer.imported_count
    assert_equal 2, importer.skipped_count
  end

  test "should handle empty CSV gracefully" do
    empty_csv = Rails.root.join("test/fixtures/files/empty_6002.csv").to_s
    File.write(empty_csv, "Asset Class,Ticker,CUSIP,Quantity,Value\n")
    
    importer = CsvHoldingsImporter.new(empty_csv)
    success = importer.call(user: @user)
    
    assert success
    assert_equal 0, importer.imported_count
    
    File.delete(empty_csv) if File.exist?(empty_csv)
  end

  test "should extract mask from various filename formats" do
    # Test with just digits
    importer1 = CsvHoldingsImporter.new("6002.csv")
    assert_equal "6002", importer1.send(:extract_mask_from_filename, "6002.csv")
    
    # Test with path
    importer2 = CsvHoldingsImporter.new("/path/to/1234.csv")
    assert_equal "1234", importer2.send(:extract_mask_from_filename, "/path/to/1234.csv")
    
    # Test with longer number
    importer3 = CsvHoldingsImporter.new("123456789.csv")
    assert_equal "6789", importer3.send(:extract_mask_from_filename, "123456789.csv")
  end
end
