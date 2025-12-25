class SyncAllItemsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting daily auto-sync for all Plaid items"
    
    PlaidItem.find_each do |item|
      SyncHoldingsJob.perform_later(item.id)
      SyncTransactionsJob.perform_later(item.id)
      SyncLiabilitiesJob.perform_later(item.id)
    end
    
    Rails.logger.info "Daily auto-sync enqueued for all items"
  end
end
