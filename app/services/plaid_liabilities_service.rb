# app/services/plaid_liabilities_service.rb
class PlaidLiabilitiesService
  def initialize(plaid_item)
    @plaid_item = plaid_item
    @client = Rails.application.config.x.plaid_client
  end

  def fetch_and_sync_liabilities
    return unless @plaid_item.access_token.present?

    request = Plaid::LiabilitiesGetRequest.new(access_token: @plaid_item.access_token)
    response = @client.liabilities_get(request)

    # Process each account's liabilities
    @plaid_item.accounts.each do |account|
      sync_account_liabilities(account, response)
    end

    # Log API cost for liabilities
    liability_count = [
      response.liabilities.credit&.size || 0,
      response.liabilities.student&.size || 0,
      response.liabilities.mortgage&.size || 0
    ].sum
    
    PlaidApiCall.log_call(
      product: 'liabilities',
      endpoint: '/liabilities/get',
      request_id: response.request_id,
      count: liability_count
    )

    response
  end

  private

  def sync_account_liabilities(account, response)
    # Credit cards
    if response.liabilities.credit
      credit_card = response.liabilities.credit.find { |cc| cc.account_id == account.account_id }
      if credit_card
        update_account_from_credit_card(account, credit_card)
      end
    end

    # Student loans
    if response.liabilities.student
      student_loan = response.liabilities.student.find { |sl| sl.account_id == account.account_id }
      if student_loan
        update_account_from_student_loan(account, student_loan)
      end
    end

    # Mortgages
    if response.liabilities.mortgage
      mortgage = response.liabilities.mortgage.find { |m| m.account_id == account.account_id }
      if mortgage
        update_account_from_mortgage(account, mortgage)
      end
    end

    # Compute debt_risk_flag after updating liability fields
    compute_debt_risk_flag(account)
  end

  def update_account_from_credit_card(account, credit_card)
    account.update!(
      apr_percentage: credit_card.aprs&.first&.apr_percentage,
      min_payment_amount: credit_card.minimum_payment_amount,
      next_payment_due_date: credit_card.next_payment_due_date,
      is_overdue: credit_card.is_overdue
    )
    
    Rails.logger.info "Updated Account #{account.id} with credit card liability data"
    log_missing_fields(account, 'credit_card')
  rescue => e
    Rails.logger.error "Failed to update credit card liability for Account #{account.id}: #{e.message}"
  end

  def update_account_from_student_loan(account, student_loan)
    account.update!(
      apr_percentage: student_loan.interest_rate_percentage,
      min_payment_amount: student_loan.minimum_payment_amount,
      next_payment_due_date: student_loan.next_payment_due_date,
      is_overdue: student_loan.is_overdue
    )
    
    Rails.logger.info "Updated Account #{account.id} with student loan liability data"
    log_missing_fields(account, 'student_loan')
  rescue => e
    Rails.logger.error "Failed to update student loan liability for Account #{account.id}: #{e.message}"
  end

  def update_account_from_mortgage(account, mortgage)
    account.update!(
      apr_percentage: mortgage.interest_rate&.percentage,
      min_payment_amount: mortgage.last_payment_amount,
      next_payment_due_date: mortgage.next_payment_due_date,
      is_overdue: mortgage.is_overdue
    )
    
    Rails.logger.info "Updated Account #{account.id} with mortgage liability data"
    log_missing_fields(account, 'mortgage')
  rescue => e
    Rails.logger.error "Failed to update mortgage liability for Account #{account.id}: #{e.message}"
  end

  def compute_debt_risk_flag(account)
    # PRD 12: Set debt_risk_flag if apr_percentage > 5% or is_overdue
    risk_flag = false
    
    if account.apr_percentage.present? && account.apr_percentage > 5.0
      risk_flag = true
      Rails.logger.info "Account #{account.id}: debt_risk_flag set due to high APR (#{account.apr_percentage}%)"
    end
    
    if account.is_overdue == true
      risk_flag = true
      Rails.logger.info "Account #{account.id}: debt_risk_flag set due to overdue status"
    end
    
    account.update!(debt_risk_flag: risk_flag)
  end

  def log_missing_fields(account, liability_type)
    missing = []
    missing << 'apr_percentage' if account.apr_percentage.nil?
    missing << 'min_payment_amount' if account.min_payment_amount.nil?
    missing << 'next_payment_due_date' if account.next_payment_due_date.nil?
    missing << 'is_overdue' if account.is_overdue.nil?
    
    if missing.any?
      Rails.logger.warn "Account #{account.id} (#{liability_type}): Missing fields from Plaid: #{missing.join(', ')}"
    end
  end
end
