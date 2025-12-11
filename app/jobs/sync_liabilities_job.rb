# app/jobs/sync_liabilities_job.rb
class SyncLiabilitiesJob < ApplicationJob
  queue_as :default
  retry_on Plaid::ApiError, wait: :exponentially_longer, attempts: 3

  def perform(plaid_item_id)
    item = PlaidItem.find_by(id: plaid_item_id)
    return unless item

    token = item.access_token
    unless token.present?
      Rails.logger.error "SyncLiabilitiesJob: access_token missing for PlaidItem #{plaid_item_id}"
      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "failure", error_message: "missing access_token", job_id: self.job_id)
      return
    end

    SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "started", job_id: self.job_id)

    begin
      client = Rails.application.config.x.plaid_client

      # Fetch liabilities from Plaid
      request = Plaid::LiabilitiesGetRequest.new(access_token: token)
      response = client.liabilities_get(request)

      # Process each account's liabilities
      item.accounts.each do |account|
        # Credit cards
        if response.liabilities.credit
          credit_cards = response.liabilities.credit.select { |cc| cc.account_id == account.account_id }
          credit_cards.each do |cc|
            account.liabilities.find_or_initialize_by(liability_id: cc.account_id).tap do |liability|
              liability.liability_type = "CREDIT_CARD"
              liability.current_balance = cc.last_statement_balance
              liability.min_payment_due = cc.minimum_payment_amount
              liability.apr_percentage = cc.aprs&.first&.apr_percentage
              liability.payment_due_date = cc.next_payment_due_date
            end.save!
          end
        end

        # Student loans
        if response.liabilities.student
          student_loans = response.liabilities.student.select { |sl| sl.account_id == account.account_id }
          student_loans.each do |sl|
            account.liabilities.find_or_initialize_by(liability_id: sl.account_id).tap do |liability|
              liability.liability_type = "STUDENT_LOAN"
              liability.current_balance = sl.last_statement_balance
              liability.min_payment_due = sl.minimum_payment_amount
              liability.apr_percentage = sl.interest_rate_percentage
              liability.payment_due_date = sl.next_payment_due_date
            end.save!
          end
        end

        # Mortgages
        if response.liabilities.mortgage
          mortgages = response.liabilities.mortgage.select { |m| m.account_id == account.account_id }
          mortgages.each do |m|
            account.liabilities.find_or_initialize_by(liability_id: m.account_id).tap do |liability|
              liability.liability_type = "MORTGAGE"
              liability.current_balance = account.current_balance
              liability.min_payment_due = m.last_payment_amount
              liability.apr_percentage = m.interest_rate.percentage
              liability.payment_due_date = m.next_payment_due_date
            end.save!
          end
        end
      end

      # Mark last successful liabilities sync timestamp (PRD 5.5)
      item.update!(liabilities_synced_at: Time.current)

      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "success", job_id: self.job_id)
      Rails.logger.info "Synced liabilities for PlaidItem #{item.id}"
    rescue Plaid::ApiError => e
      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    rescue => e
      SyncLog.create!(plaid_item: item, job_type: "liabilities", status: "failure", error_message: e.message, job_id: self.job_id)
      raise
    end
  end
end
