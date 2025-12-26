# app/jobs/daily_plaid_sync_job.rb
class DailyPlaidSyncJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform
    # PRD 0040: Loop over PlaidItems and check for stale data (no webhooks in 24h)
    PlaidItem.find_each do |item|
      if item.last_webhook_at.nil? || item.last_webhook_at < 24.hours.ago
        Rails.logger.info "DailyPlaidSyncJob: Triggering fallback sync for Item #{item.id} (Last webhook: #{item.last_webhook_at || 'Never'})"
        
        # Enqueue product-specific syncs
        SyncHoldingsJob.perform_later(item.id)
        SyncTransactionsJob.perform_later(item.id)
        SyncLiabilitiesJob.perform_later(item.id)
        
        # Throttling to avoid rate limits
        sleep 1
      else
        Rails.logger.debug "DailyPlaidSyncJob: Skipping Item #{item.id}, recent webhook received at #{item.last_webhook_at}"
      end
    end
  end
end
