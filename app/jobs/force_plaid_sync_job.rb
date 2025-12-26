class ForcePlaidSyncJob < ApplicationJob
  queue_as :default

  # PRD 0050: Force Full Update
  def perform(plaid_item_id, product)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

    # 1. Rate Limit Safeguard (max 1/item/day)
    if item.last_force_at.present? && item.last_force_at > 24.hours.ago
      Rails.logger.warn "ForcePlaidSyncJob: Rate limit hit for Item #{item.id}, product: #{product}. Last force at: #{item.last_force_at}"
      return
    end

    client = Rails.application.config.x.plaid_client

    case product.to_s.downcase
    when "transactions"
      # PRD 0050: call /transactions/refresh
      begin
        request = Plaid::TransactionsRefreshRequest.new(access_token: item.access_token)
        client.transactions_refresh(request)
        Rails.logger.info "ForcePlaidSyncJob: Initiated /transactions/refresh for Item #{item.id}"

        # Enqueue the standard sync job to pick up the results (Plaid usually sends a webhook, but we follow up)
        SyncTransactionsJob.perform_later(item.id)
      rescue Plaid::ApiError => e
        Rails.logger.error "ForcePlaidSyncJob: /transactions/refresh failed for Item #{item.id}: #{e.message}"
        raise
      end

    when "holdings"
      # PRD 0050: call /investments/refresh (for holdings)
      begin
        request = Plaid::InvestmentsRefreshRequest.new(access_token: item.access_token)
        client.investments_refresh(request)
        Rails.logger.info "ForcePlaidSyncJob: Initiated /investments/refresh for Item #{item.id}"

        SyncHoldingsJob.perform_later(item.id)
      rescue Plaid::ApiError => e
        Rails.logger.error "ForcePlaidSyncJob: /investments/refresh failed for Item #{item.id}: #{e.message}"
        raise
      end

    when "liabilities"
      # PRD 0050: Liabilities just use a full re-fetch as there is no /refresh
      SyncLiabilitiesJob.perform_later(item.id)
      Rails.logger.info "ForcePlaidSyncJob: Enqueued full SyncLiabilitiesJob for Item #{item.id}"

    else
      Rails.logger.error "ForcePlaidSyncJob: Unknown product '#{product}' for Item #{item.id}"
      return
    end

    # 2. Update last_force_at on success
    item.update!(last_force_at: Time.current)
  end
end
