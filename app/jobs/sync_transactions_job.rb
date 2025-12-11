# app/jobs/sync_transactions_job.rb
class SyncTransactionsJob < ApplicationJob
  queue_as :default
  retry_on Plaid::ApiError, wait: :exponentially, attempts: 3

  def perform(plaid_item_id)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

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
          account.transactions.find_or_initialize_by(transaction_id: txn.transaction_id).tap do |t|
            t.name = txn.name
            t.amount = txn.amount
            t.date = txn.date
            t.category = txn.category&.join(', ')
            t.merchant_name = txn.merchant_name
            t.pending = txn.pending
            t.payment_channel = txn.payment_channel
            t.iso_currency_code = txn.iso_currency_code
          end.save!
        end
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

      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced #{transactions_data.size} transactions & #{all_streams.size} recurring streams for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "transactions", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    end
  end
end
