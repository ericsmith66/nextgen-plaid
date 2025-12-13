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

        # PRD 8: Use find_or_initialize_by to support both create and update
        pos = account.holdings.find_or_initialize_by(security_id: security.security_id)
        
        # Map basic fields
        pos.symbol        = security.ticker_symbol
        pos.name          = security.name
        pos.quantity      = holding.quantity
        pos.cost_basis    = holding.cost_basis
        pos.market_value  = holding.institution_value || holding.market_value
        
        # PRD 8: Map extended fields from Plaid (handle nil gracefully)
        pos.vested_value             = holding.vested_value
        pos.institution_price        = holding.institution_price
        pos.institution_price_as_of  = holding.institution_price_as_of
        
        # PRD 9: Map securities metadata from Plaid (nullable, may require license)
        pos.isin     = security.isin
        pos.cusip    = security.cusip
        pos.sector   = security.sector || "Unknown"
        pos.industry = security.industry
        
        # PRD 8: Compute high_cost_flag (>50% gain threshold)
        if pos.cost_basis.present? && pos.cost_basis > 0 && pos.market_value.present?
          gain_ratio = (pos.market_value - pos.cost_basis) / pos.cost_basis
          pos.high_cost_flag = (gain_ratio > 0.5)
        else
          pos.high_cost_flag = false
        end
        
        # PRD 8: Log when vested_value is missing (expected for some institutions)
        if holding.vested_value.nil? && pos.quantity.to_f > 0
          Rails.logger.warn "SyncHoldingsJob: vested_value nil for holding #{security.security_id} (#{security.ticker_symbol}) in account #{plaid_account.account_id}"
        end
        
        # PRD 9: Log when securities metadata is missing (may require Plaid license or manual enrichment)
        if security.sector.nil? || security.isin.nil?
          Rails.logger.info "SyncHoldingsJob: Securities metadata incomplete for #{security.security_id} (#{security.ticker_symbol}): sector=#{security.sector.inspect}, isin=#{security.isin.inspect}"
        end
        
        # PRD 10: Map type/subtype from security (subtype may not be available on all Security objects)
        pos.type = security.type
        pos.subtype = security.respond_to?(:subtype) ? security.subtype : nil
        
        pos.save!
        
        # PRD 10: Handle FixedIncome details if present
        if security.respond_to?(:fixed_income) && security.fixed_income.present?
          fi = security.fixed_income
          
          fixed_income_record = pos.fixed_income || pos.build_fixed_income
          fixed_income_record.yield_percentage = fi.yield_percentage
          fixed_income_record.yield_type = fi.yield_type || "unknown"
          fixed_income_record.maturity_date = fi.maturity_date
          fixed_income_record.issue_date = fi.issue_date
          fixed_income_record.face_value = fi.face_value
          
          # PRD 10: Set income_risk_flag if yield < 2%
          if fi.yield_percentage.present? && fi.yield_percentage.to_f < 2.0
            fixed_income_record.income_risk_flag = true
          else
            fixed_income_record.income_risk_flag = false
          end
          
          fixed_income_record.save!
          
          # PRD 10: HNW Hook - Log tax-exempt bonds for DAF strategies
          if fi.yield_type&.downcase&.include?("tax-exempt")
            Rails.logger.info "SyncHoldingsJob: Tax-exempt bond detected for HNW philanthropy hook: #{security.security_id} (#{security.ticker_symbol})"
          end
        end
        
        # PRD 10: Handle OptionContract details if present
        if security.respond_to?(:option_contract) && security.option_contract.present?
          oc = security.option_contract
          
          option_record = pos.option_contract || pos.build_option_contract
          option_record.contract_type = oc.contract_type
          option_record.expiration_date = oc.expiration_date
          option_record.strike_price = oc.strike_price
          option_record.underlying_ticker = oc.underlying_ticker
          
          option_record.save!
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