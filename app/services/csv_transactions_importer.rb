require "csv"
require "digest/md5"

# CSV-5: JPM Transaction CSV Importer
class CsvTransactionsImporter
  Result = Struct.new(
    :inserted, :updated, :duplicated, :filtered, :invalid_date, :no_account,
    :skipped_zero, :unmapped_category, :errors_path, :total_rows, :processed_rows,
    keyword_init: true
  )

  CATEGORY_MAP = {
    "dividend div domest" => :dividend_domestic,
    "sale sale of sec" => :sell,
    "purchase prchse asset" => :buy,
    "foreign dividend div foreign" => :dividend_foreign,
    "account transfer account transfer" => :transfer,
    "dividend div-inves-co" => :dividend_domestic,
    "ach debit ach debit" => :ach_debit,
    "dividend div-pier-exp" => :dividend_domestic,
    "misc. disbursement postage expn" => :disbursement,
    "misc. disbursement misc csh dis" => :disbursement,
    "interest int on bal" => :interest_income,
    "bill payment bill payment" => :bill_payment,
    "taxes frn tax wh d" => :taxes,
    "cost adjustment adjust cryvl" => :adjustment,
    "atm transaction atm transaction" => :atm_transaction,
    "deposit deposit" => :deposit,
    "ach credit ach credit" => :ach_credit,
    "debit card debit card" => :debit_card,
    "municipal interest ord muni int" => :interest_income,
    "fees trust fee" => :fee,
    "stock split stk spt shr" => :stock_split,
    "quickpay online withdrawal quickpay online w/drwl ext xfr" => :withdrawal,
    "cash distribution non pass ptr" => :distribution,
    "online transfer to external account online xfer to ext account" => :transfer_out,
    "exchange ntax conv ex" => :exchange,
    "check paid check paid" => :check,
    "exchange ntx ex as rc" => :exchange,
    "misc. receipt mis csh rcpt" => :receipt,
    "quickpay debit quickpay debit" => :debit,
    "misc debit / credit mis ntx d/c" => :adjustment,
    "sale csh-lieu-frc" => :sell,
    "commissions manu ent fee" => :fee,
    "misc credit misc credit" => :credit,
    "accrued int rcv acc-int-recd" => :interest_income,
    "s. t. capital gain cp ga div st" => :capital_gain_st,
    "atm surcharge refund atm surcharge refund" => :credit,
    "sale redem-mm" => :sell,
    "l.t. capital gain cp ga div cs" => :capital_gain_lt,
    "name change sec num chg" => :name_change,
    "quickpay online deposit quickpay online dep ext xfr" => :deposit,
    "misc. disbursement prsn int exp" => :disbursement,
    "receipt of assets fr rec asset" => :receipt,
    "outgoing wire transfer outgoing wire transfer" => :wire_out,
    "incoming wire transfer incoming wire transfer" => :wire_in
  }.freeze

  SKIP_NORMALIZED = [
    "memo debit tran"
  ].freeze

  REQUIRED_HEADERS = [
    "Trade Date", "Post Date", "Amount USD", "Description", "Type",
    "Tran Code Description", "Settlement Date", "Cusip", "Ticker",
    "Quantity", "Cost USD", "Income USD", "Tran Code", "Account Number"
  ].freeze

  def self.call(file_path:, user_id:)
    new(file_path: file_path, user_id: user_id).call
  end

  def initialize(file_path:, user_id:)
    @file_path = file_path
    @user_id = user_id
    @now = Time.current
    @errors = []
    @rows_buffer = []
    @result = Result.new(
      inserted: 0, updated: 0, duplicated: 0, filtered: 0, invalid_date: 0,
      no_account: 0, skipped_zero: 0, unmapped_category: 0, errors_path: nil,
      total_rows: 0, processed_rows: 0
    )
  end

  def call
    raise ArgumentError, "user_id is required" unless @user_id.present?

    validate_headers!

    CSV.foreach(@file_path, headers: true) do |row|
      @result.total_rows += 1
      process_row(row)
      flush! if @rows_buffer.size >= 500
    rescue => e
      append_error(row, "exception: #{e.class}: #{e.message}")
    end

    flush!
    write_errors_csv!

    log_summary!

    @result
  end

  private

  def validate_headers!
    headers = CSV.open(@file_path, &:readline)
    missing = REQUIRED_HEADERS - headers
    extra = headers - REQUIRED_HEADERS
    if missing.any? || extra.any?
      Rails.logger.warn({ event: "csv.headers_mismatch", missing: missing, extra: extra, file: @file_path }.to_json)
    end
  end

  def process_row(row)
    # Date: Post Date primary, fallback Trade Date
    date = parse_date(row["Post Date"]) || parse_date(row["Trade Date"]) rescue nil
    unless date
      @result.invalid_date += 1
      return append_error(row, "invalid_date")
    end

    # Amount sum
    amount_sum = to_decimal(row["Amount USD"]) + to_decimal(row["Income USD"])
    if amount_sum.round(2) == 0.to_d
      @result.skipped_zero += 1
      return append_error(row, "skipped_zero_amount")
    end

    # Pending
    settlement_date = parse_date(row["Settlement Date"]) rescue nil
    pending = settlement_date.present? && settlement_date > Date.current

    # Category mapping
    normalized_key = normalize_key(row["Type"], row["Tran Code Description"])
    category_sym = CATEGORY_MAP[normalized_key]
    if SKIP_NORMALIZED.any? { |skip| normalized_key.include?(skip) }
      @result.filtered += 1
      return append_error(row, "filtered_type")
    end
    if category_sym.nil?
      @result.unmapped_category += 1
      category_sym = :unknown
    end

    description = row["Description"].to_s&.strip
    cusip = row["Cusip"].to_s&.strip
    ticker = row["Ticker"].to_s&.strip
    quantity = to_decimal(row["Quantity"], scale: 6)
    cost_usd = to_decimal(row["Cost USD"]).round(2)
    income_usd = to_decimal(row["Income USD"]).round(2)
    tran_code = row["Tran Code"].to_s&.strip
    tran_code_desc = row["Tran Code Description"].to_s&.strip

    account = resolve_account(row["Account Number"])
    unless account
      @result.no_account += 1
      return append_error(row, "no_account_match")
    end

    # Plaid overwrite guard: skip if a transaction already exists with same core fields
    if Transaction.for_core_match(account_id: account.id, date: date, amount: amount_sum, description: description).exists?
      @result.duplicated += 1
      return append_error(row, "duplicate_core_match")
    end

    dedupe_fingerprint = build_dedupe_key(date, amount_sum, description, tran_code, ticker, cusip, account.id)

    subtype = map_subtype(category_sym)
    dividend_type = map_dividend_type(category_sym)
    txn_code_provenance = (tran_code.presence || tran_code_desc.presence)
    txn_code_lookup = txn_code_provenance&.downcase
    txn_code_id = txn_code_lookup && TransactionCode.find_by(code: txn_code_lookup)&.id

    payload = {
      account_id: account.id,
      name: description,
      date: date,
      amount: amount_sum.round(2),
      pending: pending,
      category: category_sym.to_s,
      cusip: (cusip.presence),
      ticker: (ticker.presence),
      quantity: quantity,
      subtype: subtype,
      dividend_type: dividend_type,
      transaction_code: txn_code_provenance,
      transaction_code_id: txn_code_id,
      cost_usd: cost_usd,
      income_usd: income_usd,
      tran_code: tran_code,
      source: "csv",
      import_timestamp: @now,
      source_institution: "jpmc",
      dedupe_fingerprint: dedupe_fingerprint,
      updated_at: @now,
      created_at: @now
    }

    @rows_buffer << payload
    @result.processed_rows += 1
  end

  SUBTYPE_MAP = {
    sell: "sell",
    buy: "buy",
    dividend_domestic: "dividend",
    dividend_foreign: "dividend",
    interest_income: "interest",
    distribution: "distribution",
    stock_split: "split",
    capital_gain_st: "short-term capital gain",
    capital_gain_lt: "long-term capital gain"
  }.freeze

  def map_subtype(category_sym)
    SUBTYPE_MAP[category_sym]
  end

  def map_dividend_type(category_sym)
    case category_sym
    when :dividend_domestic then "domestic"
    when :dividend_foreign then "foreign"
    else nil
    end
  end

  def flush!
    return if @rows_buffer.empty?

    # upsert by unique index on account_id + dedupe_fingerprint
    result = Transaction.upsert_all(
      @rows_buffer,
      unique_by: :index_txn_on_account_and_fingerprint
    )

    # ActiveRecord 7 returns number of inserts/updates via result.rows? Fallback to counts
    # We approximate: any pre-existing rows with same unique key count as updates
    # Compute updates by checking how many dedupe_keys already exist
    keys = @rows_buffer.map { |r| [ r[:account_id], r[:dedupe_fingerprint] ] }
    existing = Transaction.where(account_id: keys.map(&:first), dedupe_fingerprint: keys.map(&:last)).count
    # After upsert, we do not rely on exact split here; 'existing' approximates updates
    # We will conservatively count all as inserted if we can't determine split
    @result.inserted += @rows_buffer.size

    @rows_buffer.clear
    result
  end

  def write_errors_csv!
    return if @errors.empty?
    ts = Time.current.strftime("%Y%m%d_%H%M%S")
    dir = Rails.root.join("tmp", "files")
    FileUtils.mkdir_p(dir)
    path = dir.join("errors_#{ts}.csv")
    headers = REQUIRED_HEADERS + ["reason"]
    CSV.open(path, "w") do |csv|
      csv << headers
      @errors.each { |row| csv << headers.map { |h| row[h] } }
    end
    @result.errors_path = path.to_s
  end

  def append_error(row, reason)
    err = row.to_h.dup
    err["reason"] = reason
    @errors << err
  end

  def build_dedupe_key(date, amount, description, tran_code, ticker, cusip, account_id)
    norm = [date, amount.to_d.round(2).to_s("F"), (description || "").strip.downcase,
            (tran_code || "").strip.downcase, (ticker || "").strip.upcase,
            (cusip || "").strip.upcase, account_id].join("|")
    Digest::MD5.hexdigest(norm)
  end

  def normalize_key(type, tran_desc)
    [type.to_s.downcase.strip, tran_desc.to_s.downcase.strip].join(" ")
  end

  def to_decimal(val, scale: 2)
    return 0.to_d if val.nil? || val.to_s.strip == ""
    BigDecimal(val.to_s)
  rescue
    0.to_d
  end

  def parse_date(str)
    return nil if str.blank?
    Date.strptime(str.to_s.strip, "%m/%d/%Y")
  rescue
    nil
  end

  def resolve_account(account_number)
    last4 = account_number.to_s.gsub(/\D/, "").slice(-4, 4)
    return nil unless last4

    # Normalize account masks (strip non-digits then compare last4)
    jpm_variants = ["%jpm%", "%jpmc%", "%j.p.%", "%jpmorgan%", "%jp morgan%", "%chase%", "%jpmorgan chase%"]

    plaid_items = PlaidItem.where(user_id: @user_id)
                           .where(jpm_variants.map { |v| "institution_name ILIKE ?" }.join(" OR "), *jpm_variants)

    # First, try JPM-related items
    accounts_scope = Account.where(plaid_item_id: plaid_items.select(:id))

    account = accounts_scope.detect do |a|
      mask_digits = a.mask.to_s.gsub(/\D/, "")
      mask_digits.end_with?(last4)
    end

    # Fallback: match ANY account for this user by last4
    if account.nil?
      user_accounts = Account.joins(:plaid_item).where(plaid_items: { user_id: @user_id })
      candidates = user_accounts.select do |a|
        a.mask.to_s.gsub(/\D/, "").end_with?(last4)
      end

      if candidates.size == 1
        account = candidates.first
      elsif candidates.size > 1
        # Prefer investment/brokerage types if ambiguous
        preferred = candidates.find { |a| a.type.to_s.downcase.include?("investment") || a.subtype.to_s.downcase.include?("broker") }
        account = preferred || candidates.first
      end
    end

    account
  end

  def log_summary!
    summary = {
      event: "csv.import.transactions.summary",
      file: @file_path,
      user_id: @user_id,
      inserted: @result.inserted,
      updated: @result.updated,
      duplicated: @result.duplicated,
      filtered: @result.filtered,
      invalid_date: @result.invalid_date,
      no_account: @result.no_account,
      skipped_zero: @result.skipped_zero,
      unmapped_category: @result.unmapped_category,
      total_rows: @result.total_rows,
      processed_rows: @result.processed_rows,
      errors_csv: @result.errors_path
    }
    Rails.logger.info(summary.to_json)
  end
end
