class MissionControlController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner

  def index
    @plaid_items = PlaidItem.includes(:accounts, :positions).order(created_at: :desc)
    @transactions = Transaction.includes(:enriched_transaction, account: :plaid_item).order(date: :desc).limit(20)
    @recurring_transactions = RecurringTransaction.includes(:plaid_item).order(created_at: :desc).limit(20)
    @accounts = Account.includes(:plaid_item, :positions, :transactions).order(created_at: :desc)
    @positions = Position.includes(account: :plaid_item).order(created_at: :desc)
    @liabilities = Liability.includes(account: :plaid_item).order(created_at: :desc)
  end

  def nuke
    # Delete in dependency order
    Transaction.delete_all
    Position.delete_all
    Liability.delete_all
    RecurringTransaction.delete_all
    Account.delete_all
    SyncLog.delete_all
    PlaidItem.delete_all

    flash[:notice] = "All Plaid data has been deleted."
    redirect_to mission_control_path
  end

  def sync_holdings_now
    count = 0
    PlaidItem.find_each do |item|
      SyncHoldingsJob.perform_later(item.id)
      count += 1
    end
    flash[:notice] = "Enqueued holdings sync for #{count} item(s)."
    redirect_to mission_control_path
  end

  def sync_transactions_now
    count = 0
    PlaidItem.find_each do |item|
      SyncTransactionsJob.perform_later(item.id)
      count += 1
    end
    flash[:notice] = "Enqueued transactions sync for #{count} item(s)."
    redirect_to mission_control_path
  end

  def sync_liabilities_now
    count = 0
    PlaidItem.find_each do |item|
      SyncLiabilitiesJob.perform_later(item.id)
      count += 1
    end
    flash[:notice] = "Enqueued liabilities sync for #{count} item(s)."
    redirect_to mission_control_path
  end

  # PRD 5.3: Refresh Everything Now - syncs all three products for all items
  def refresh_everything_now
    count = 0
    PlaidItem.find_each do |item|
      SyncHoldingsJob.perform_later(item.id)
      SyncTransactionsJob.perform_later(item.id)
      SyncLiabilitiesJob.perform_later(item.id)
      count += 1
    end
    flash[:notice] = "Enqueued full sync (holdings + transactions + liabilities) for #{count} item(s)."
    redirect_to mission_control_path
  end

  # Returns a Plaid Link token for update mode (re-linking an existing item)
  def relink
    item = PlaidItem.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless item

    client = Rails.application.config.x.plaid_client
    
    # Try update mode first with the existing access token
    begin
      request = Plaid::LinkTokenCreateRequest.new(
        user: { client_user_id: item.user_id.to_s },
        client_name: "NextGen Wealth Advisor",
        products: ["investments", "transactions", "liabilities"],
        country_codes: ["US"],
        language: "en",
        access_token: item.access_token
      )
      response = client.link_token_create(request)
      render json: { link_token: response.link_token }
    rescue Plaid::ApiError => e
      # If the access token is invalid, fall back to standard link mode (no update)
      error_code = extract_plaid_error_code(e)
      if error_code == "INVALID_ACCESS_TOKEN"
        Rails.logger.warn("PlaidItem #{item.id} has invalid token, creating standard link token instead")
        request = Plaid::LinkTokenCreateRequest.new(
          user: { client_user_id: item.user_id.to_s },
          client_name: "NextGen Wealth Advisor",
          products: ["investments", "transactions", "liabilities"],
          country_codes: ["US"],
          language: "en"
        )
        response = client.link_token_create(request)
        render json: { link_token: response.link_token }
      else
        Rails.logger.error("Re-link failed for PlaidItem #{item.id}: #{e.message}")
        render json: { error: "Plaid error: #{e.message}" }, status: :bad_gateway
      end
    end
  end

  # Called by the UI after Plaid Link update-mode succeeds, to auto-enqueue a holdings sync
  def relink_success
    item = PlaidItem.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless item

    # If public_token is provided (fallback to standard link mode), exchange it for a new access_token
    if params[:public_token].present?
      client = Rails.application.config.x.plaid_client
      exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: params[:public_token])
      exchange_response = client.item_public_token_exchange(exchange_request)
      
      # Update the item with the new access_token
      item.update!(
        access_token: exchange_response.access_token,
        status: :good,
        reauth_attempts: 0,
        last_error: nil
      )
    else
      # PRD 6.3: Reset status to good and clear error state after successful re-link (update mode)
      item.update!(status: :good, reauth_attempts: 0, last_error: nil)
    end

    SyncHoldingsJob.perform_later(item.id)
    render json: { status: "ok" }
  end

  # Returns last 20 sync logs as JSON (owner-only)
  def logs
    logs = SyncLog.includes(:plaid_item).order(created_at: :desc).limit(20)
    render json: logs.map { |l|
      {
        id: l.id,
        plaid_item_id: l.plaid_item_id,
        institution_name: l.plaid_item&.institution_name,
        job_type: l.job_type,
        status: l.status,
        error_message: l.error_message,
        created_at: l.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        job_id: l.job_id
      }
    }
  end

  # PRD 7.7: Cost Tracker page
  def costs
    # Current month
    @current_month = Date.today.beginning_of_month
    @current_year = @current_month.year
    @current_month_number = @current_month.month
    
    # Calculate current month totals
    @current_month_total = ApiCostLog.monthly_total(@current_year, @current_month_number)
    @current_month_breakdown = ApiCostLog.monthly_breakdown(@current_year, @current_month_number)
    
    # Previous month
    @previous_month = @current_month - 1.month
    @previous_year = @previous_month.year
    @previous_month_number = @previous_month.month
    @previous_month_total = ApiCostLog.monthly_total(@previous_year, @previous_month_number)
    
    # Recent cost logs
    @recent_logs = ApiCostLog.order(created_at: :desc).limit(20)
    
    # Projection: based on current month's daily average
    days_in_month = @current_month.end_of_month.day
    days_elapsed = Date.today.day
    if days_elapsed > 0 && @current_month_total > 0
      daily_average = @current_month_total.to_f / days_elapsed
      @projected_total = (daily_average * days_in_month).ceil
    else
      @projected_total = 0
    end
  end

  private

  # Helper method to extract error_code from Plaid::ApiError
  def extract_plaid_error_code(error)
    return nil unless error.respond_to?(:response_body)
    parsed = JSON.parse(error.response_body) rescue {}
    parsed["error_code"]
  end
end
