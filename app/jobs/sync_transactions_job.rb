# app/jobs/sync_transactions_job.rb
class SyncTransactionsJob < ApplicationJob
  queue_as :default

  # Placeholder for MVP — safe no-op that can be extended later
  def perform(plaid_item_id)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

    Rails.logger.info "SyncTransactionsJob: placeholder run for PlaidItem #{item.id}"
  end
end
