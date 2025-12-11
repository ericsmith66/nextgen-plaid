# app/jobs/sync_transactions_job.rb
class SyncTransactionsJob < ApplicationJob
  queue_as :default

  # Placeholder for MVP — safe no-op that can be extended later
  def perform(plaid_item_id)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

    SyncLog.create!(plaid_item: item, job_type: "transactions", status: "started")
    begin
      # Placeholder work — in the future, fetch and upsert transactions here
      Rails.logger.info "SyncTransactionsJob: placeholder run for PlaidItem #{item.id}"
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "success")
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: e.message)
      raise
    end
  end
end
