# app/jobs/sync_liabilities_job.rb
class SyncLiabilitiesJob < ApplicationJob
  queue_as :default
  retry_on Plaid::ApiError, wait: :exponentially_longer, attempts: 5
  
  # If token is permanently bad, give up and alert
  discard_on Plaid::ApiError do |job, error|
    error_code = SyncLiabilitiesJob.extract_plaid_error_code(error)
    if error_code == "INVALID_ACCESS_TOKEN"
      plaid_item_id = job.arguments.first
      Rails.logger.error "PlaidItem #{plaid_item_id} has invalid token — needs re-link"
      item = PlaidItem.find_by(id: plaid_item_id)
      if item
        SyncLog.create!(
          plaid_item: item,
          job_type: "liabilities",
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
    return if should_skip_sync? && skip_non_prod!(item, "liabilities")

    # PRD 6.6: Skip syncing items with failed status
    if item.status == 'failed'
      Rails.logger.warn "SyncLiabilitiesJob: Skipping PlaidItem #{plaid_item_id} with failed status"
      return
    end

    token = item.access_token
    unless token.present?
      Rails.logger.error "SyncLiabilitiesJob: access_token missing for PlaidItem #{plaid_item_id}"
      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "failure", error_message: "missing access_token", job_id: self.job_id)
      return
    end

    SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "started", job_id: self.job_id)

    begin
      # PRD 0030 Bugfix: Ensure accounts exist before syncing liabilities.
      # After a 'nuke', accounts are gone. Webhooks might trigger this job before SyncHoldingsJob runs.
      if item.accounts.empty?
        Rails.logger.info "SyncLiabilitiesJob: No accounts found for Item #{item.id}, performing holdings/accounts sync first"
        SyncHoldingsJob.perform_now(item.id)
        item.reload
      end

      # PRD 12: Use PlaidLiabilitiesService to fetch and sync liability data to Account model
      service = PlaidLiabilitiesService.new(item)
      service.fetch_and_sync_liabilities

      # Mark last successful liabilities sync timestamp (PRD 5.5)
      item.update!(liabilities_synced_at: Time.current)

      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced liabilities for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      # PRD 6.1: Detect expired/broken tokens
      error_code = self.class.extract_plaid_error_code(e)
      if error_code == "ADDITIONAL_CONSENT_REQUIRED"
        # Graceful handling: mark item for reauth (consent), log, and do not re-raise
        item.update!(status: :needs_reauth, last_error: e.message)
        SyncLog.create!(
          plaid_item: item,
          job_type: "liabilities",
          status: "failure",
          error_message: "ADDITIONAL_CONSENT_REQUIRED - user must grant Liabilities access",
          job_id: self.job_id
        )
        Rails.logger.warn({ event: "liabilities.consent_required", item_id: item.id, request_id: (JSON.parse(e.response_body)["request_id"] rescue nil) }.to_json)
        return
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
      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "failure", error_message: e.message, job_id: self.job_id)
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
