# app/jobs/sync_transactions_job.rb
class SyncTransactionsJob < ApplicationJob
  queue_as :default
  retry_on Plaid::ApiError, wait: :exponentially_longer, attempts: 5
  
  # If token is permanently bad, give up and alert
  discard_on Plaid::ApiError do |job, error|
    error_code = SyncTransactionsJob.extract_plaid_error_code(error)
    if error_code == "INVALID_ACCESS_TOKEN"
      plaid_item_id = job.arguments.first
      Rails.logger.error "PlaidItem #{plaid_item_id} has invalid token — needs re-link"
      item = PlaidItem.find_by(id: plaid_item_id)
      if item
        SyncLog.create!(
          plaid_item: item,
          job_type: "transactions",
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

    # PRD 6.6: Skip syncing items with failed status
    if item.status == 'failed'
      Rails.logger.warn "SyncTransactionsJob: Skipping PlaidItem #{plaid_item_id} with failed status"
      return
    end

    token = item.access_token
    unless token.present?
      Rails.logger.error "SyncTransactionsJob: access_token missing for PlaidItem #{plaid_item_id}"
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: "missing access_token", job_id: self.job_id)
      return
    end

    SyncLog.create!(plaid_item: item, job_type: "transactions", status: "started", job_id: self.job_id)

    begin
      client = Rails.application.config.x.plaid_client

      # 1. Fetch transactions for last 730 days
      end_date = Date.today
      start_date = end_date - 730.days

      request = Plaid::TransactionsGetRequest.new(
        access_token: token,
        start_date: start_date,
        end_date: end_date
      )
      response = client.transactions_get(request)
      transactions_data = response.transactions

      # Upsert transactions
      item.accounts.each do |account|
        account_transactions = transactions_data.select { |t| t.account_id == account.account_id }
        account_transactions.each do |txn|
          transaction = account.transactions.find_or_initialize_by(transaction_id: txn.transaction_id).tap do |t|
            t.name = txn.name
            t.amount = txn.amount
            t.date = txn.date
            t.category = txn.category&.join(', ')
            t.merchant_name = txn.merchant_name
            t.pending = txn.pending
            t.payment_channel = txn.payment_channel
            t.iso_currency_code = txn.iso_currency_code
          end
          transaction.save!
          
          # PRD 7.1-7.2: Extract and save enrichment data (only once per transaction)
          unless transaction.enriched_transaction.present?
            create_enriched_transaction(transaction, txn)
          end
        end
      end

      # PRD 11: Fetch investment transactions for investment accounts
      investment_accounts = item.accounts.where(type: 'investment')
      if investment_accounts.any?
        inv_request = Plaid::InvestmentsTransactionsGetRequest.new(
          access_token: token,
          start_date: start_date,
          end_date: end_date
        )
        inv_response = client.investments_transactions_get(inv_request)
        investment_transactions_data = inv_response.investment_transactions
        securities_data = inv_response.securities

        investment_accounts.each do |account|
          account_inv_transactions = investment_transactions_data.select { |t| t.account_id == account.account_id }
          account_inv_transactions.each do |inv_txn|
            security = securities_data.find { |s| s.security_id == inv_txn.security_id }
            
            transaction = account.transactions.find_or_initialize_by(transaction_id: inv_txn.investment_transaction_id).tap do |t|
              # Basic fields
              t.name = inv_txn.name
              t.amount = inv_txn.amount
              t.date = inv_txn.date
              t.iso_currency_code = inv_txn.iso_currency_code
              
              # PRD 11: Investment-specific fields
              t.fees = inv_txn.fees
              t.subtype = inv_txn.subtype
              t.price = inv_txn.price
              
              # PRD 11: Dividend type for HNW tax hooks
              if inv_txn.subtype&.downcase&.include?("dividend")
                t.dividend_type = inv_txn.subtype
                Rails.logger.info "SyncTransactionsJob: Dividend detected for HNW tax hook: #{inv_txn.investment_transaction_id} (#{inv_txn.subtype})"
              end
            end
            transaction.save!
            
            # PRD 11: Compute wash sale risk flag if sell transaction
            if inv_txn.subtype&.downcase == "sell" && inv_txn.security_id.present?
              compute_wash_sale_flag(transaction, inv_txn.security_id, inv_txn.date, item)
            end
          end
        end

        # PRD 11: Log API cost for investment transactions
        PlaidApiCall.log_call(
          product: 'investments_transactions',
          endpoint: '/investments/transactions/get',
          request_id: inv_response.request_id,
          count: investment_transactions_data.size
        )
      end

      # 2. Fetch recurring transactions
      recurring_request = Plaid::TransactionsRecurringGetRequest.new(access_token: token)
      recurring_response = client.transactions_recurring_get(recurring_request)
      inflow_streams = recurring_response.inflow_streams || []
      outflow_streams = recurring_response.outflow_streams || []

      all_streams = inflow_streams.map { |s| { stream: s, type: 'inflow' } } +
                    outflow_streams.map { |s| { stream: s, type: 'outflow' } }

      all_streams.each do |stream_data|
        stream = stream_data[:stream]
        item.recurring_transactions.find_or_initialize_by(stream_id: stream.stream_id).tap do |rt|
          rt.description = stream.description
          rt.average_amount = stream.average_amount&.amount
          rt.frequency = stream.frequency
          rt.stream_type = stream_data[:type]
        end.save!
      end

      # Mark last successful transactions sync timestamp (PRD 5.5)
      item.update!(transactions_synced_at: Time.current)

      # PRD 8.2: Log API cost for transactions
      PlaidApiCall.log_call(
        product: 'transactions',
        endpoint: '/transactions/get',
        request_id: response.request_id,
        count: transactions_data.size
      )

      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced #{transactions_data.size} transactions & #{all_streams.size} recurring streams for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      # PRD 6.1: Detect expired/broken tokens
      error_code = self.class.extract_plaid_error_code(e)
      
      # Handle PRODUCT_NOT_READY - transient error when product isn't ready yet
      if error_code == "PRODUCT_NOT_READY"
        Rails.logger.warn "PlaidItem #{item.id} transactions product not ready yet - will retry: #{e.message}"
        SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: "PRODUCT_NOT_READY - will retry later", job_id: self.job_id)
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
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    end
  end

  # Helper method to extract error_code from Plaid::ApiError
  def self.extract_plaid_error_code(error)
    return nil unless error.respond_to?(:response_body)
    parsed = JSON.parse(error.response_body) rescue {}
    parsed["error_code"]
  end

  private

  # PRD 11: Compute wash sale risk flag
  # Detects if a sell transaction may trigger wash sale rule (buy of same security within 30 days)
  def compute_wash_sale_flag(sell_transaction, security_id, sell_date, item)
    return unless security_id.present? && sell_date.present?
    
    # Look for buy transactions of the same security within 30 days (before or after sell date)
    date_range = (sell_date - 30.days)..(sell_date + 30.days)
    
    # Search across all user's accounts for potential wash sale
    user = item.user
    buy_exists = Transaction.joins(account: { plaid_item: :user })
                           .where(users: { id: user.id })
                           .where(subtype: ['buy', 'Buy', 'BUY'])
                           .where(date: date_range)
                           .joins('INNER JOIN holdings ON holdings.account_id = transactions.account_id')
                           .where(holdings: { security_id: security_id })
                           .exists?
    
    if buy_exists
      sell_transaction.update_column(:wash_sale_risk_flag, true)
      Rails.logger.info "SyncTransactionsJob: Wash sale risk detected for transaction #{sell_transaction.transaction_id} (security: #{security_id})"
    end
  rescue => e
    # PRD 11: Graceful degradation - log error but continue
    Rails.logger.error "Failed to compute wash sale flag for transaction #{sell_transaction.transaction_id}: #{e.message}"
  end

  # PRD 7.1-7.2: Extract enrichment data from Plaid transaction and create EnrichedTransaction
  def create_enriched_transaction(transaction, plaid_txn)
    # Extract personal finance category
    pfc = plaid_txn.personal_finance_category
    category_string = if pfc
      primary = pfc.primary || ""
      detailed = pfc.detailed || ""
      detailed.present? ? "#{primary} → #{detailed}" : primary
    else
      nil
    end

    # Extract confidence level from personal_finance_category or counterparties
    confidence = if pfc&.respond_to?(:confidence_level)
      pfc.confidence_level
    elsif plaid_txn.respond_to?(:counterparties) && plaid_txn.counterparties&.any?
      plaid_txn.counterparties.first&.confidence_level
    else
      "UNKNOWN"
    end

    # Extract merchant logo and website from counterparties
    logo_url = nil
    website = nil
    if plaid_txn.respond_to?(:counterparties) && plaid_txn.counterparties&.any?
      counterparty = plaid_txn.counterparties.first
      logo_url = counterparty&.logo_url
      website = counterparty&.website
    end

    # Create enriched transaction record
    EnrichedTransaction.create!(
      source_transaction: transaction,
      merchant_name: plaid_txn.merchant_name || plaid_txn.name,
      logo_url: logo_url,
      website: website,
      personal_finance_category: category_string,
      confidence_level: confidence
    )
  rescue => e
    # PRD 7.10: Graceful degradation - log error but continue
    Rails.logger.error "Failed to create enriched transaction for #{transaction.transaction_id}: #{e.message}"
  end
end
