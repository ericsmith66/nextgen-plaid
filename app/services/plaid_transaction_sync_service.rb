# app/services/plaid_transaction_sync_service.rb
class PlaidTransactionSyncService
  def initialize(plaid_item)
    @item = plaid_item
    @client = Rails.application.config.x.plaid_client
  end

  def sync
    cursor = @item.sync_cursor
    added = []
    modified = []
    removed = []
    has_more = true

    while has_more
      request = Plaid::TransactionsSyncRequest.new(
        access_token: @item.access_token,
        cursor: cursor,
        count: 500
      )
      
      response = @client.transactions_sync(request)
      
      added += response.added
      modified += response.modified
      removed += response.removed
      
      # Log API call
      PlaidApiCall.log_call(
        product: 'transactions',
        endpoint: '/transactions/sync',
        request_id: response.request_id,
        count: response.added.size + response.modified.size + response.removed.size
      )
      
      has_more = response.has_more
      cursor = response.next_cursor
    end

    ActiveRecord::Base.transaction do
      process_removed(removed)
      process_added(added)
      process_modified(modified)
      
      @item.update!(sync_cursor: cursor)
    end

    { added: added.size, modified: modified.size, removed: removed.size }
  rescue Plaid::ApiError => e
    handle_plaid_error(e)
  end

  private

  def process_added(transactions)
    transactions.each do |txn|
      account = @item.accounts.find_by(account_id: txn.account_id)
      next unless account

      # PRD 0020: Use create_or_find_by to handle race conditions during concurrent syncs.
      # We include source: "plaid" to satisfy the DB default and avoid 'manual' validation triggers.
      transaction = account.transactions.create_or_find_by!(transaction_id: txn.transaction_id, source: "plaid")
      update_transaction_fields(transaction, txn)
      transaction.save!
    end
  end

  def process_modified(transactions)
    process_added(transactions)
  end

  def process_removed(removed_metadata)
    removed_ids = removed_metadata.map(&:transaction_id)
    # PRD 0020: Soft-deletion
    @item.transactions.where(transaction_id: removed_ids).update_all(deleted_at: Time.current)
  end

  def update_transaction_fields(transaction, txn)
    transaction.assign_attributes(
      name: txn.name,
      amount: txn.amount,
      date: txn.date,
      category: txn.category&.join(', '),
      merchant_name: txn.merchant_name,
      pending: txn.pending,
      payment_channel: txn.payment_channel,
      iso_currency_code: txn.iso_currency_code,
      source: "plaid",
      deleted_at: nil # Restore if it was previously soft-deleted
    )
  end

  def handle_plaid_error(e)
    error_response = JSON.parse(e.response_body) rescue {}
    error_code = error_response['error_code']
    
    Rails.logger.error "Plaid Sync Error for Item #{@item.id}: #{e.message}"
    
    if %w[ITEM_LOGIN_REQUIRED INVALID_ACCESS_TOKEN].include?(error_code)
      @item.update!(status: :needs_reauth, last_error: e.message)
    end
    
    raise e
  end
end
