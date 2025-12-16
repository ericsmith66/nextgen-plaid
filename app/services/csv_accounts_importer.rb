# app/services/csv_accounts_importer.rb
# CSV-3: Service to import accounts from CSV files
require 'csv'

class CsvAccountsImporter
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
      Rails.logger.error("CSV Import Error: File not found: #{@file_path}")
      return false
    end

    plaid_item = find_or_create_mock_plaid_item(user)
    return false unless plaid_item

    ActiveRecord::Base.transaction do
      CSV.foreach(@file_path, headers: true, header_converters: :symbol).with_index(2) do |row, line_num|
        process_row(row, plaid_item, line_num)
      end
    end

    log_completion
    true
  rescue CSV::MalformedCSVError => e
    @errors << "Malformed CSV: #{e.message}"
    Rails.logger.error("CSV Import Error: Malformed CSV - #{e.message}")
    false
  rescue StandardError => e
    @errors << "Import failed: #{e.message}"
    Rails.logger.error("CSV Import Error: #{e.class} - #{e.message}")
    false
  end

  private

  def find_or_create_mock_plaid_item(user)
    PlaidItem.find_or_create_by!(
      user: user,
      institution_id: 'jpmc',
      institution_name: 'JPMorgan Chase'
    ) do |item|
      item.item_id = "mock_jpmc_#{user.id}_#{Time.current.to_i}"
      item.status = 'good'
      item.access_token = nil
    end
  rescue StandardError => e
    @errors << "Failed to create PlaidItem: #{e.message}"
    Rails.logger.error("CSV Import Error: Failed to create PlaidItem - #{e.message}")
    nil
  end

  def process_row(row, plaid_item, line_num)
    account_number = row[:account_number]&.strip

    if account_number.blank?
      skip_row(line_num, "Missing Account Number")
      return
    end

    # Extract last 4 digits for mask
    mask = extract_mask(account_number)
    if mask.blank?
      skip_row(line_num, "Invalid Account Number format")
      return
    end

    # Parse balance
    balance = parse_balance(row[:balance])
    if balance.nil? || balance.zero?
      skip_row(line_num, "Invalid or zero balance")
      return
    end

    # Map type to enum
    account_type = map_account_type(row[:type])
    if account_type.blank?
      skip_row(line_num, "Invalid account type: #{row[:type]}")
      return
    end

    # Create or update account
    account = Account.find_or_initialize_by(
      plaid_item: plaid_item,
      account_id: account_number,
      source: :csv
    )

    account.assign_attributes(
      mask: mask,
      name: row[:accounts]&.strip,
      type: account_type,
      subtype: row[:account_description]&.strip,
      current_balance: balance,
      trust_code: row[:trust]&.strip,
      source: :csv,
      source_institution: 'jpmc',
      import_timestamp: Time.current
    )

    if account.save
      @imported_count += 1
      Rails.logger.info("CSV Import: Imported account #{account_number} (line #{line_num})")
    else
      skip_row(line_num, "Validation failed: #{account.errors.full_messages.join(', ')}")
    end
  rescue StandardError => e
    skip_row(line_num, "Error processing row: #{e.message}")
  end

  def extract_mask(account_number)
    # Extract last 4 digits from account number (e.g., '...7008' or '1234567008')
    cleaned = account_number.gsub(/[^0-9]/, '')
    cleaned.length >= 4 ? cleaned[-4..-1] : nil
  end

  def parse_balance(balance_str)
    return nil if balance_str.blank?

    # Remove currency symbols, commas, and spaces
    cleaned = balance_str.to_s.gsub(/[$,\s]/, '')
    Float(cleaned)
  rescue ArgumentError, TypeError
    nil
  end

  def map_account_type(type_str)
    return nil if type_str.blank?

    case type_str.strip.downcase
    when 'checking'
      'checking'
    when 'savings'
      'savings'
    when 'invt mgmt', 'investment', 'brokerage'
      'investment'
    when 'credit card', 'credit'
      'credit'
    when 'loan'
      'loan'
    else
      nil
    end
  end

  def skip_row(line_num, reason)
    @skipped_count += 1
    @errors << "Skipped row #{line_num}: #{reason}"
    Rails.logger.warn("CSV Import: Skipped row #{line_num}: #{reason}")
  end

  def log_completion
    message = "CSV Import complete: #{@imported_count} records added, #{@skipped_count} skipped"
    Rails.logger.info(message)
  end
end
