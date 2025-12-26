# app/services/plaid_holdings_sync_service.rb
class PlaidHoldingsSyncService
  def initialize(plaid_item)
    @item = plaid_item
    @client = Rails.application.config.x.plaid_client
  end

  def sync
    token = @item.access_token
    return unless token.present?

    response = @client.investments_holdings_get(
      Plaid::InvestmentsHoldingsGetRequest.new(access_token: token)
    )

    ActiveRecord::Base.transaction do
      sync_accounts(response.accounts)
      sync_holdings(response.holdings, response.securities)
      
      # Mark last successful holdings sync timestamp (PRD 5.5)
      @item.update!(holdings_synced_at: Time.current, last_holdings_sync_at: Time.current)
    end

    # PRD 8.2: Log API cost for holdings
    PlaidApiCall.log_call(
      product: 'investments_holdings',
      endpoint: '/investments/holdings/get',
      request_id: response.request_id,
      count: response.holdings.size
    )

    { accounts: response.accounts.size, holdings: response.holdings.size }
  rescue Plaid::ApiError => e
    handle_plaid_error(e)
  end

  private

  def sync_accounts(plaid_accounts)
    plaid_accounts.each do |plaid_account|
      persistent_id = plaid_account.persistent_account_id rescue nil
      
      account = find_account(plaid_account, persistent_id)
      
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
        account = @item.accounts.create_or_find_by!(account_id: plaid_account.account_id) do |acc|
          acc.persistent_account_id = persistent_id
          acc.name = plaid_account.name
          acc.mask = plaid_account.mask
          acc.type = plaid_account.type
          acc.subtype = plaid_account.subtype
          acc.current_balance = plaid_account.balances.current
          acc.iso_currency_code = plaid_account.balances.iso_currency_code
        end
        # Ensure it's updated if it was found instead of created
        account.update!(
          persistent_account_id: persistent_id,
          name: plaid_account.name,
          mask: plaid_account.mask,
          type: plaid_account.type,
          subtype: plaid_account.subtype,
          current_balance: plaid_account.balances.current,
          iso_currency_code: plaid_account.balances.iso_currency_code
        )
      end
    end
  end

  def find_account(plaid_account, persistent_id)
    account = nil
    if persistent_id.present?
      account = @item.accounts.find_by(persistent_account_id: persistent_id)
    end
    
    account ||= @item.accounts.find_by(account_id: plaid_account.account_id)
    
    account ||= @item.accounts.find_by(
      name: plaid_account.name,
      mask: plaid_account.mask,
      type: plaid_account.type
    )
    
    account
  end

  def sync_holdings(plaid_holdings, plaid_securities)
    plaid_holdings.each do |holding|
      account = @item.accounts.find_by(account_id: holding.account_id)
      next unless account

      security = plaid_securities.find { |s| s.security_id == holding.security_id }
      next unless security

      pos = account.holdings.create_or_find_by!(security_id: security.security_id, source: "plaid")
      
      pos.assign_attributes(
        symbol: security.ticker_symbol,
        name: security.name,
        quantity: holding.quantity,
        cost_basis: holding.cost_basis,
        market_value: holding.institution_value || holding.market_value,
        vested_value: holding.vested_value,
        institution_price: holding.institution_price,
        institution_price_as_of: holding.institution_price_as_of,
        isin: security.isin,
        cusip: security.cusip,
        sector: security.sector || "Unknown",
        industry: security.industry,
        type: security.type,
        subtype: security.respond_to?(:subtype) ? security.subtype : nil,
        source: "plaid"
      )
      
      compute_high_cost_flag(pos)
      pos.save!
      
      sync_fixed_income(pos, security)
      sync_option_contract(pos, security)
    end
  end

  def compute_high_cost_flag(pos)
    if pos.cost_basis.present? && pos.cost_basis > 0 && pos.market_value.present?
      gain_ratio = (pos.market_value - pos.cost_basis) / pos.cost_basis
      pos.high_cost_flag = (gain_ratio > 0.5)
    else
      pos.high_cost_flag = false
    end
  end

  def sync_fixed_income(pos, security)
    if security.respond_to?(:fixed_income) && security.fixed_income.present?
      fi = security.fixed_income
      
      fixed_income_record = pos.fixed_income || pos.create_fixed_income!(yield_type: "unknown") rescue pos.fixed_income
      fixed_income_record.assign_attributes(
        yield_percentage: fi.yield_percentage,
        yield_type: fi.yield_type || "unknown",
        maturity_date: fi.maturity_date,
        issue_date: fi.issue_date,
        face_value: fi.face_value
      )
      
      fixed_income_record.income_risk_flag = (fi.yield_percentage.present? && fi.yield_percentage.to_f < 2.0)
      fixed_income_record.save!
      
      if fi.yield_type&.downcase&.include?("tax-exempt")
        Rails.logger.info "PlaidHoldingsSyncService: Tax-exempt bond detected: #{security.security_id}"
      end
    end
  end

  def sync_option_contract(pos, security)
    if security.respond_to?(:option_contract) && security.option_contract.present?
      oc = security.option_contract
      
      option_record = pos.option_contract || pos.create_option_contract! rescue pos.option_contract
      option_record.assign_attributes(
        contract_type: oc.contract_type,
        expiration_date: oc.expiration_date,
        strike_price: oc.strike_price,
        underlying_ticker: oc.underlying_ticker
      )
      
      option_record.save!
    end
  end

  def handle_plaid_error(e)
    error_response = JSON.parse(e.response_body) rescue {}
    error_code = error_response['error_code']
    
    Rails.logger.error "Plaid Holdings Sync Error for Item #{@item.id}: #{e.message}"
    
    if %w[ITEM_LOGIN_REQUIRED INVALID_ACCESS_TOKEN].include?(error_code)
      @item.update!(status: :needs_reauth, last_error: e.message)
    end
    
    raise e
  end
end
