# app/jobs/sync_holdings_job.rb
class SyncHoldingsJob < ApplicationJob
  queue_as :default

  # Retry on Plaid errors (e.g., rate limits, temporary failures)
  retry_on Plaid::ApiError, wait: :exponentially_longer, attempts: 5

  # If token is permanently bad, give up and alert
  discard_on Plaid::ApiError do |job, error|
    if error.error_code == "INVALID_ACCESS_TOKEN"
      Rails.logger.error "PlaidItem #{job.arguments.first} has invalid token — needs re-link"
    end
  end

  def perform(plaid_item_id)
    item = PlaidItem.find(plaid_item_id)
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
      account = item.accounts.find_or_create_by(account_id: plaid_account.account_id) do |a|
        a.name               = plaid_account.name
        a.mask               = plaid_account.mask
        a.type               = plaid_account.type
        a.subtype            = plaid_account.subtype
        a.current_balance    = plaid_account.balances.current
        a.iso_currency_code  = plaid_account.balances.iso_currency_code
      end

      # Holdings are top-level — match by account_id
      response.holdings.select { |h| h.account_id == plaid_account.account_id }.each do |holding|
        security = response.securities.find { |s| s.security_id == holding.security_id }
        next unless security

        account.positions.find_or_create_by(security_id: security.security_id) do |pos|
          pos.symbol        = security.ticker_symbol
          pos.name          = security.name
          pos.quantity      = holding.quantity
          pos.cost_basis    = holding.cost_basis
          pos.market_value  = holding.institution_value || holding.market_value
        end
      end
    end

      # Mark last successful holdings sync timestamp
      item.update!(last_holdings_sync_at: Time.current)

      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced #{item.accounts.count} accounts & #{item.positions.count} positions for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "holdings", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    end
  end
end