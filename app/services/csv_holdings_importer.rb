# app/services/csv_holdings_importer.rb
# CSV-2: Service to import holdings from CSV files
require "csv"

class CsvHoldingsImporter
  attr_reader :file_path, :errors, :imported_count, :skipped_count

  def initialize(file_path)
    @file_path = file_path
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  def call(user:)
    unless File.exist?(@file_path)
      @errors << "File not found: #{@file_path}"
      Rails.logger.error("CSV Holdings Import Error: File not found: #{@file_path}")
      return false
    end

    # Extract account mask from filename (e.g., "6002.csv" -> "6002")
    account_mask = extract_mask_from_filename(@file_path)
    unless account_mask
      @errors << "Cannot extract account mask from filename: #{File.basename(@file_path)}"
      Rails.logger.error("CSV Holdings Import Error: Cannot extract mask from #{@file_path}")
      return false
    end

    # Find account by mask
    account = find_account_by_mask(account_mask, user)
    unless account
      @errors << "No account found with mask '#{account_mask}' for user #{user.id}"
      Rails.logger.warn("CSV Holdings Import: No account found with mask '#{account_mask}'")
      return false
    end

    Rails.logger.info("CSV Holdings Import: Starting import for account #{account.id} (mask: #{account_mask})")

    ActiveRecord::Base.transaction do
      CSV.foreach(@file_path, headers: true, header_converters: :symbol).with_index(2) do |row, line_num|
        process_row(row, account, line_num)
      end
    end

    log_completion(account)
    true
  rescue CSV::MalformedCSVError => e
    @errors << "Malformed CSV: #{e.message}"
    Rails.logger.error("CSV Holdings Import Error: Malformed CSV - #{e.message}")
    false
  rescue StandardError => e
    @errors << "Import failed: #{e.message}"
    Rails.logger.error("CSV Holdings Import Error: #{e.class} - #{e.message}")
    false
  end

  private

  def extract_mask_from_filename(file_path)
    # Extract last 4 digits from filename (e.g., "6002.csv" -> "6002", "/path/to/1234.csv" -> "1234")
    basename = File.basename(file_path, ".*")
    digits = basename.gsub(/[^0-9]/, "")
    digits.length >= 4 ? digits[-4..-1] : nil
  end

  def find_account_by_mask(mask, user)
    # Find account by mask for this user (through plaid_items)
    Account.joins(:plaid_item)
           .where(plaid_items: { user_id: user.id })
           .find_by(mask: mask)
  end

  def process_row(row, account, line_num)
    asset_class = row[:asset_class]&.strip
    ticker = row[:ticker]&.strip
    cusip = row[:cusip]&.strip
    quantity_str = row[:quantity]&.strip

    # Filter: Skip footer rows and invalid asset classes
    if should_skip_row?(asset_class, ticker, cusip, quantity_str, line_num)
      return
    end

    # Parse quantity
    quantity = parse_decimal(quantity_str)
    if quantity.nil? || quantity <= 0
      skip_row(line_num, "Invalid or zero quantity: #{quantity_str}")
      return
    end

    # Parse market value
    market_value = parse_decimal(row[:value])
    if market_value.nil?
      skip_row(line_num, "Invalid market value: #{row[:value]}")
      return
    end

    # Map type from Asset Class
    type = map_asset_class_to_type(asset_class)
    subtype = row[:asset_strategy_detail]&.strip

    # Parse other fields
    security_id = cusip.presence || "#{ticker}_#{account.id}_csv"
    
    # Use ticker if present, otherwise use CUSIP or description
    symbol = ticker.presence || cusip.presence || row[:description]&.strip&.first(10)

    # Create or update holding
    holding = Holding.find_or_initialize_by(
      account: account,
      security_id: security_id,
      source: :csv
    )

    holding.assign_attributes(
      symbol: symbol,
      name: row[:description]&.strip,
      type: type,
      subtype: subtype,
      quantity: quantity,
      cost_basis: parse_decimal(row[:cost]),
      market_value: market_value,
      institution_price: parse_decimal(row[:price]),
      institution_price_as_of: parse_datetime(row[:pricing_date]),
      unrealized_gl: parse_decimal(row[:unrealized_gl_amt]),
      acquisition_date: parse_date(row[:acquisition_date]),
      isin: row[:isin]&.strip,
      ytm: parse_decimal(row[:ytm]),
      maturity_date: parse_date(row[:maturity_date]),
      disclaimers: build_disclaimers(row),
      source: :csv,
      source_institution: "jpmc",
      import_timestamp: Time.current
    )

    if holding.save
      @imported_count += 1
      Rails.logger.info("CSV Holdings Import: Imported #{ticker} (line #{line_num})")
    else
      skip_row(line_num, "Validation failed: #{holding.errors.full_messages.join(", ")}")
    end
  rescue StandardError => e
    skip_row(line_num, "Error processing row: #{e.message}")
  end

  def should_skip_row?(asset_class, ticker, cusip, quantity_str, line_num)
    # Skip rows with invalid asset classes (footers, etc.)
    if asset_class.blank? || %w[FOOTNOTES P W X A C].include?(asset_class.upcase)
      skip_row(line_num, "Footer or invalid asset class detected: #{asset_class}")
      return true
    end

    # Skip rows with blank ticker AND blank cusip (need at least one identifier)
    if ticker.blank? && cusip.blank?
      skip_row(line_num, "Blank ticker and CUSIP")
      return true
    end

    # Skip rows with blank quantity
    if quantity_str.blank?
      skip_row(line_num, "Blank quantity")
      return true
    end

    false
  end

  def map_asset_class_to_type(asset_class)
    return nil if asset_class.blank?

    normalized = asset_class.strip.downcase
    
    case normalized
    when "equity"
      "stock"
    when "cash", "cash equivalent"
      "cash_equivalent"
    when /fixed income/
      "fixed_income"
    else
      asset_class.strip
    end
  end

  def parse_decimal(value_str)
    return nil if value_str.blank?

    # Remove currency symbols, commas, and spaces
    cleaned = value_str.to_s.gsub(/[$,\s]/, "")
    BigDecimal(cleaned)
  rescue ArgumentError, TypeError, BigDecimal::InvalidOperation
    nil
  end

  def parse_datetime(datetime_str)
    return nil if datetime_str.blank?

    # Parse MM/DD/YYYY HH:MM:SS format
    DateTime.strptime(datetime_str, "%m/%d/%Y %H:%M:%S")
  rescue ArgumentError, TypeError, Date::Error
    nil
  end

  def parse_date(date_str)
    return nil if date_str.blank?

    Date.parse(date_str)
  rescue ArgumentError, TypeError
    nil
  end

  def build_disclaimers(row)
    disclaimers = {}
    cost_disclaimer = row[:disclaimerscost]&.strip
    quantity_disclaimer = row[:disclaimersquantity]&.strip

    disclaimers[:cost] = cost_disclaimer if cost_disclaimer.present?
    disclaimers[:quantity] = quantity_disclaimer if quantity_disclaimer.present?

    disclaimers.present? ? disclaimers : nil
  end

  def skip_row(line_num, reason)
    @skipped_count += 1
    @errors << "Skipped row #{line_num}: #{reason}"
    Rails.logger.warn("CSV Holdings Import: Skipped row #{line_num}: #{reason}")
  end

  def log_completion(account)
    message = "CSV Holdings Import complete for account #{account.id}: #{@imported_count} records added, #{@skipped_count} skipped"
    Rails.logger.info(message)
  end
end
