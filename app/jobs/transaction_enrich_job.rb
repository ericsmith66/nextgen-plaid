class TransactionEnrichJob < ApplicationJob
  queue_as :default

  retry_on StandardError, attempts: 3, wait: :exponentially_longer

  def perform(transaction_ids)
    return unless feature_enabled?
    txns = Transaction.where(id: Array(transaction_ids))
    TransactionEnricher.call(txns)
  end

  private

  def feature_enabled?
    ENV.fetch("PLAID_ENRICH_ENABLED", "false").to_s == "true"
  end
end
