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
    item = PlaidItem.find(plaid_item_id)
    
    # PRD 6.6: Skip syncing items with failed status
    if item.status == 'failed'
      Rails.logger.warn "SyncHoldingsJob: Skipping PlaidItem #{plaid_item_id} with failed status"
      return
    end

    token = item.access_token

    unless token.present?
      Rails.logger.error "SyncHoldingsJob: access_token missing for PlaidItem #{plaid_item_id}"
      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "failure", error_message: "missing access_token", job_id: self.job_id)
      return
    end

    SyncLog.create!(plaid_item: item, job_type: "holdings", status: "started", job_id: self.job_id)

    client = Rails.application.config.x.plaid_client
    begin
      response = client.investments_holdings_get(
        Plaid::InvestmentsHoldingsGetRequest.new(access_token: token)
      )

    response.accounts.each do |plaid_account|
      # Extract persistent_account_id (stable across re-auth) if available
      persistent_id = plaid_account.persistent_account_id rescue nil
      
      # Try to find existing account by persistent_account_id first (most reliable)
      account = nil
      if persistent_id.present?
        account = item.accounts.find_by(persistent_account_id: persistent_id)
      end
      
      # If not found by persistent_id, try account_id
      if account.nil?
        account = item.accounts.find_by(account_id: plaid_account.account_id)
      end
      
      # If not found, try to match by name, mask, and type (handles legacy accounts without persistent_id)
      if account.nil?
        account = item.accounts.find_by(
          name: plaid_account.name,
          mask: plaid_account.mask,
          type: plaid_account.type
        )
      end
      
      # If we found an existing account, update it with current data
      if account
        account.update!(
          account_id: plaid_account.account_id,
          persistent_account_id: persistent_id,
          name: plaid_account.name,
          mask: plaid_account.mask,
          type: plaid_account.type,
          subtype: plaid_account.subtype,
          current_balance: plaid_account.balances.current,
          iso_currency_code: plaid_account.balances.iso_currency_code
        )
      else
        # Create new account if no match found
        account = item.accounts.create!(
          account_id: plaid_account.account_id,
          persistent_account_id: persistent_id,
          name: plaid_account.name,
          mask: plaid_account.mask,
          type: plaid_account.type,
          subtype: plaid_account.subtype,
          current_balance: plaid_account.balances.current,
          iso_currency_code: plaid_account.balances.iso_currency_code
        )
      end

      # Holdings are top-level — match by account_id
      response.holdings.select { |h| h.account_id == plaid_account.account_id }.each do |holding|
        security = response.securities.find { |s| s.security_id == holding.security_id }
        next unless security

        account.holdings.find_or_create_by(security_id: security.security_id) do |pos|
          pos.symbol        = security.ticker_symbol
          pos.name          = security.name
          pos.quantity      = holding.quantity
          pos.cost_basis    = holding.cost_basis
          pos.market_value  = holding.institution_value || holding.market_value
        end
      end
    end

      # Mark last successful holdings sync timestamp (PRD 5.5)
      item.update!(holdings_synced_at: Time.current, last_holdings_sync_at: Time.current)

      # PRD 8.2: Log API cost for holdings
      PlaidApiCall.log_call(
        product: 'investments_holdings',
        endpoint: '/investments/holdings/get',
        request_id: response.request_id,
        count: response.holdings.size
      )

      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced #{item.accounts.count} accounts & #{item.holdings.count} holdings for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      # PRD 6.1: Detect expired/broken tokens
      error_code = self.class.extract_plaid_error_code(e)
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