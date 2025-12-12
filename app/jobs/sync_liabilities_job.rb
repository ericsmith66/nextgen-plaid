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
