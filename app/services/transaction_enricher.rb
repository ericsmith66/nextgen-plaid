class TransactionEnricher
  DEFAULT_DAILY_LIMIT = 1000

  def self.call(records)
    new(records).call
  end

  def initialize(records)
    @records = Array(records).compact
  end

  def call
    return 0 if @records.empty?
    return 0 unless feature_enabled?
    remaining = daily_remaining
    return 0 if remaining <= 0

    processed = 0
    @records.first([ remaining, @records.length ].min).each do |txn|
      with_retries do
        enrich_one!(txn)
        processed += 1
      end
    rescue => e
      Rails.logger.warn({ event: "uc14.enrich.error", transaction_id: txn.id, error: e.class.name, message: e.message }.to_json)
    end

    increment_daily(processed)
    Rails.logger.info({ event: "uc14.enrich.summary", processed: processed }.to_json)
    processed
  end

  private

  def feature_enabled?
    ENV.fetch("PLAID_ENRICH_ENABLED", "false").to_s == "true"
  end

  def daily_key
    date = Date.current.strftime("%Y%m%d")
    "uc14:enrich:count:#{date}"
  end

  def daily_limit
    (ENV["PLAID_ENRICH_DAILY_LIMIT"] || DEFAULT_DAILY_LIMIT).to_i
  end

  def daily_remaining
    return daily_limit unless redis_available?
    used = redis.get(daily_key).to_i
    [ daily_limit - used, 0 ].max
  end

  def increment_daily(n)
    return unless redis_available?
    redis.multi do |r|
      r.incrby(daily_key, n)
      r.expire(daily_key, 86_400)
    end
  end

  def redis
    @redis ||= defined?(Redis) ? Redis.new(url: ENV["REDIS_URL"]) : nil
  end

  def redis_available?
    !!redis
  end

  def with_retries(max: 3)
    attempt = 0
    begin
      attempt += 1
      yield
    rescue => e
      raise if attempt >= max
      sleep(0.25 * (2 ** (attempt - 1)))
      retry
    end
  end

  # Placeholder implementation: wire to Plaid /transactions/enrich later
  def enrich_one!(txn)
    # Example: attach a counterparties skeleton if missing
    txn.counterparties ||= []
    if txn.merchant_entity_id.present? && txn.counterparties.none? { |c| c["entity_id"] == txn.merchant_entity_id }
      txn.counterparties << {
        "name" => txn.merchant_name || txn.name,
        "entity_id" => txn.merchant_entity_id,
        "type" => "merchant",
        "confidence_level" => txn.personal_finance_category_confidence_level || "unknown"
      }
    end
    txn.save!
  end
end
