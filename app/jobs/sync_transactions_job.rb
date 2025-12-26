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

    # PRD PROD-TEST-01: Guard production API calls
    return if should_skip_sync? && skip_non_prod!(item, "transactions")

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
      # PRD 0030 Bugfix: Ensure accounts exist before syncing transactions.
      # After a 'nuke', accounts are gone. Webhooks might trigger this job before SyncHoldingsJob runs.
      if item.accounts.empty?
        Rails.logger.info "SyncTransactionsJob: No accounts found for Item #{item.id}, performing holdings/accounts sync first"
        # We use perform_now to ensure accounts are created before we continue to transactions
        SyncHoldingsJob.perform_now(item.id)
        item.reload
      end

      # PRD 0020: Use PlaidTransactionSyncService for cursor-based incremental sync
      sync_service = PlaidTransactionSyncService.new(item)
      sync_result = sync_service.sync
      
      # PRD 11: Sync investment transactions
      sync_investments(item)
      
      # PRD 12: Sync recurring transactions
      sync_recurring(item)

      Rails.logger.info "SyncTransactionsJob complete for Item #{item.id}: #{sync_result}"
      
      # Mark last successful transactions sync timestamp
      item.update!(transactions_synced_at: Time.current)

      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "success", job_id: self.job_id)
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

  # PRD 11: Sync investment transactions for item
  def sync_investments(item)
    request = Plaid::InvestmentsTransactionsGetRequest.new(
      access_token: item.access_token,
      start_date: (Date.today - 30.days).strftime('%Y-%m-%d'),
      end_date: Date.today.strftime('%Y-%m-%d')
    )
    
    response = Rails.application.config.x.plaid_client.investments_transactions_get(request)
    
    # Log API call
    PlaidApiCall.log_call(
      product: 'investments',
      endpoint: '/investments/transactions/get',
      request_id: response.request_id,
      count: response.investment_transactions.size
    )

    process_investment_transactions(item, response.investment_transactions, response.securities)
  rescue Plaid::ApiError => e
    Rails.logger.error "SyncTransactionsJob: investments_transactions_get failed for Item #{item.id}: #{e.message}"
    # Non-fatal for the whole job
  end

  # PRD 12: Sync recurring transactions for item
  def sync_recurring(item)
    request = Plaid::TransactionsRecurringGetRequest.new(access_token: item.access_token)
    response = Rails.application.config.x.plaid_client.transactions_recurring_get(request)
    
    # Log API call
    request_id = begin
                   response.request_id
                 rescue
                   nil
                 end
    PlaidApiCall.log_call(
      product: 'transactions',
      endpoint: '/transactions/recurring/get',
      request_id: request_id,
      count: response.inflow_streams.size + response.outflow_streams.size
    )

    process_recurring_transactions(item, response.outflow_streams)
  rescue Plaid::ApiError => e
    Rails.logger.error "SyncTransactionsJob: transactions_recurring_get failed for Item #{item.id}: #{e.message}"
    # Non-fatal for the whole job
  end

  private

  def process_investment_transactions(item, transactions, securities)
    transactions.each do |txn|
      account = item.accounts.find_by(account_id: txn.account_id)
      next unless account

      # PRD 11: Use create_or_find_by to handle race conditions during concurrent syncs.
      # We include source: "plaid" to satisfy the DB default and avoid 'manual' validation triggers.
      transaction = account.transactions.create_or_find_by!(transaction_id: txn.investment_transaction_id, source: "plaid")
      
      transaction.assign_attributes(
        name: txn.name,
        amount: txn.amount,
        date: txn.date,
        subtype: txn.subtype,
        price: txn.price,
        fees: txn.fees,
        iso_currency_code: txn.iso_currency_code,
        source: "plaid"
      )
      
      # PRD 11: Map dividend subtypes to dividend_type
      if txn.subtype.to_s.downcase.include?('dividend')
        transaction.dividend_type = if txn.subtype.to_s.downcase.include?('qualified')
          :qualified
        elsif txn.subtype.to_s.downcase.include?('non-qualified')
          :non_qualified
        else
          :unknown
        end
      end
      
      transaction.save!
      
      # PRD 11: Compute wash sale risk for sells
      if txn.subtype.to_s.downcase == 'sell'
        compute_wash_sale_flag(transaction, txn.security_id, txn.date, item)
      end
    end
  end

  def process_recurring_transactions(item, outflow_streams)
    outflow_streams.each do |stream|
      recurring = item.recurring_transactions.find_or_initialize_by(stream_id: stream.stream_id)
      recurring.assign_attributes(
        category: stream.category&.join(', '),
        description: stream.description,
        merchant_name: stream.merchant_name,
        frequency: stream.frequency,
        last_amount: stream.last_amount&.amount,
        last_date: stream.last_date,
        status: stream.status
      )
      recurring.save!
    end
  end

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
