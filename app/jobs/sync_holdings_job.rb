# app/jobs/sync_holdings_job.rb
class SyncHoldingsJob < ApplicationJob
  queue_as :default

  # Retry on Plaid errors (e.g., rate limits, temporary failures)
  retry_on Plaid::ApiError, wait: :exponentially_longer, attempts: 5

  # If token is permanently bad, give up and alert
  discard_on Plaid::ApiError do |job, error|
    error_code = SyncHoldingsJob.extract_plaid_error_code(error)
    if error_code == "INVALID_ACCESS_TOKEN"
      plaid_item_id = job.arguments.first
      Rails.logger.error "PlaidItem #{plaid_item_id} has invalid token — needs re-link"
      item = PlaidItem.find_by(id: plaid_item_id)
      if item
        SyncLog.create!(
          plaid_item: item,
          job_type: "holdings",
          status: "failure",
          error_message: "INVALID_ACCESS_TOKEN - needs re-link",
          job_id: job.job_id
        )
      end
    end
  end

  def perform(plaid_item_id)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

    # PRD PROD-TEST-01: Guard production API calls
    return if should_skip_sync? && skip_non_prod!(item, "holdings")

    # PRD 6.6: Skip syncing items with failed status
    if item.status == 'failed'
      Rails.logger.warn "SyncHoldingsJob: Skipping PlaidItem #{plaid_item_id} with failed status"
      return
    end

    SyncLog.create!(plaid_item: item, job_type: "holdings", status: "started", job_id: self.job_id)

    begin
      service = PlaidHoldingsSyncService.new(item)
      result = service.sync

      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced #{result[:accounts]} accounts & #{result[:holdings]} holdings for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      # PRD 6.1: Detect expired/broken tokens
      error_code = self.class.extract_plaid_error_code(e)
      
      # Handle PRODUCT_NOT_READY - transient error when product isn't ready yet
      if error_code == "PRODUCT_NOT_READY"
        Rails.logger.warn "PlaidItem #{item.id} holdings product not ready yet - will retry: #{e.message}"
        SyncLog.create!(plaid_item: item, job_type: "holdings", status: "failure", error_message: "PRODUCT_NOT_READY - will retry later", job_id: self.job_id)
        # Re-raise to allow retry_on to handle the retry logic
        raise
      end
      
      if error_code == "ITEM_LOGIN_REQUIRED" || error_code == "INVALID_ACCESS_TOKEN"
        new_attempts = item.reauth_attempts + 1
        # PRD 6.6: After 3 failed attempts, mark as failed
        new_status = new_attempts >= 3 ? :failed : :needs_reauth
        item.update!(
          status: new_status,
          last_error: e.message,
          reauth_attempts: new_attempts
        )
        Rails.logger.error "PlaidItem #{item.id} needs reauth (attempt #{new_attempts}): #{e.message}"
      end
      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    end
  end

  # Helper method to extract error_code from Plaid::ApiError
  def self.extract_plaid_error_code(error)
    return nil unless error.respond_to?(:response_body)
    parsed = JSON.parse(error.response_body) rescue {}
    parsed["error_code"]
  end
end