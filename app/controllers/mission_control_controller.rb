class MissionControlController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner

  def index
    @plaid_items = PlaidItem.includes(:accounts, :holdings).order(created_at: :desc)
    @transactions = Transaction.includes(:enriched_transaction, account: :plaid_item).order(date: :desc).limit(20)
    @recurring_transactions = RecurringTransaction.includes(:plaid_item).order(created_at: :desc).limit(20)
    @accounts = Account.includes(:plaid_item, :holdings, :transactions).order(created_at: :desc)
    @holdings = Holding.includes(account: :plaid_item).order(created_at: :desc)
    # PRD 12: Liability data now stored directly on Account model
    
    # PRD UI-3: Load sync logs with filters
    @sync_logs = SyncLog.includes(:plaid_item).order(created_at: :desc)
    @webhook_logs = WebhookLog.includes(:plaid_item).order(created_at: :desc).limit(10)
    
    # Filter by job type if provided
    if params[:job_type].present? && SyncLog::JOB_TYPES.include?(params[:job_type])
      @sync_logs = @sync_logs.where(job_type: params[:job_type])
    end
    
    # Filter by status if provided
    if params[:status].present? && SyncLog::STATUSES.include?(params[:status])
      @sync_logs = @sync_logs.where(status: params[:status])
    end
    
    # Filter by date range if provided
    if params[:start_date].present?
      begin
        start_date = Date.parse(params[:start_date])
        @sync_logs = @sync_logs.where('created_at >= ?', start_date.beginning_of_day)
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end
    
    if params[:end_date].present?
      begin
        end_date = Date.parse(params[:end_date])
        @sync_logs = @sync_logs.where('created_at <= ?', end_date.end_of_day)
      rescue ArgumentError
        # Invalid date format, ignore filter
      end
    end
    
    # Paginate logs
    @sync_logs = @sync_logs.page(params[:page]).per(25)
  end

  def nuke
    # PRD 8.4: Delete everything EXCEPT plaid_api_calls and sync_logs (cost history preserved forever)
    # Delete in dependency order
    EnrichedTransaction.delete_all
    Transaction.delete_all
    FixedIncome.delete_all
    OptionContract.delete_all
    Holding.delete_all
    # PRD 12: Liability model removed - data now on Account model
    RecurringTransaction.delete_all
    Account.delete_all
    SyncLog.delete_all  # Delete sync_logs to avoid foreign key constraint violation
    WebhookLog.delete_all
    # PRD 0020: We reset cursors before deleting items (if we were keeping them), 
    # but since we are deleting them, this is just to be safe if the logic changes.
    PlaidItem.update_all(sync_cursor: nil)
    PlaidItem.delete_all
    # PlaidApiCall is kept for audit trail and billing history

    flash[:notice] = "All Plaid data deleted — cost history preserved."
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
    # Optional gate
    if ENV.fetch("LIABILITIES_ENABLED", "true").to_s != "true"
      flash[:alert] = "Liabilities sync is disabled by configuration."
      return redirect_to mission_control_path
    end
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
    # Allow product-specific consent flows (e.g., liabilities)
    requested_products = params[:products].to_s.split(',').map(&:strip).reject(&:blank?)
    # Default to all configured products if none specified
    products = if requested_products.any?
                 requested_products
               else
                 ["investments", "transactions", "liabilities"]
               end

    # Try update mode first with the existing access token
    begin
      request = Plaid::LinkTokenCreateRequest.new(
        user: { client_user_id: item.user_id.to_s },
        client_name: "NextGen Wealth Advisor",
        products: products,
        country_codes: ["US"],
        language: "en",
        access_token: item.access_token,
        redirect_uri: ENV["PLAID_REDIRECT_URI"],
        transactions: Plaid::LinkTokenTransactions.new(days_requested: 730)
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
          products: products,
          country_codes: ["US"],
          language: "en",
          redirect_uri: ENV["PLAID_REDIRECT_URI"],
          transactions: Plaid::LinkTokenTransactions.new(days_requested: 730)
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

    products = params[:products].to_s.split(',').map(&:strip)

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

    # Enqueue follow-up syncs based on products
    if products.include?("liabilities")
      SyncLiabilitiesJob.perform_later(item.id)
    end
    SyncHoldingsJob.perform_later(item.id)
    render json: { status: "ok" }
  end

  # PRD: Plaid Item Removal - Remove a PlaidItem and invalidate on Plaid's side
  def remove_item
    start_time = Time.current
    item = PlaidItem.find_by(id: params[:id])
    
    unless item
      flash[:alert] = "Item not found"
      redirect_to mission_control_path
      return
    end

    begin
      # Call Plaid API to invalidate the item on their side
      client = Rails.application.config.x.plaid_client
      request = Plaid::ItemRemoveRequest.new(access_token: item.access_token)
      client.item_remove(request)
      
      # Log successful removal (without exposing token)
      Rails.logger.info "Item removed from Plaid: item_id=#{item.item_id}, institution=#{item.institution_name}"
      
      # Destroy the PlaidItem (cascades to accounts, holdings, transactions, etc.)
      item.destroy!
      
      # Benchmark operation
      elapsed = ((Time.current - start_time) * 1000).round
      Rails.logger.info "Item removal completed in #{elapsed}ms"
      
      flash[:notice] = "Item removed successfully"
      redirect_to mission_control_path
    rescue Plaid::ApiError => e
      Rails.logger.error "Plaid API error removing item #{item.id}: #{e.message}"
      flash[:alert] = "Removal failed: #{e.message}"
      redirect_to mission_control_path
    rescue StandardError => e
      Rails.logger.error "Error removing item #{item.id}: #{e.message}"
      flash[:alert] = "Removal failed: #{e.message}"
      redirect_to mission_control_path
    end
  end

  # PRD 0030: Fire a Sandbox webhook for testing
  def fire_webhook
    item = PlaidItem.find_by(id: params[:id])
    unless item
      flash[:alert] = "Item not found"
      return redirect_to mission_control_path
    end

    webhook_code = params[:webhook_code] || "SYNC_UPDATES_AVAILABLE"
    webhook_type = params[:webhook_type] || "TRANSACTIONS"
    client = Rails.application.config.x.plaid_client

    begin
      request = Plaid::SandboxItemFireWebhookRequest.new(
        access_token: item.access_token,
        webhook_code: webhook_code,
        webhook_type: webhook_type
      )
      client.sandbox_item_fire_webhook(request)
      
      flash[:notice] = "Sandbox webhook '#{webhook_code}' fired for #{item.institution_name}. Check logs for receipt."
    rescue Plaid::ApiError => e
      error_response = JSON.parse(e.response_body) rescue {}
      error_code = error_response['error_code']
      
      if error_code == "SANDBOX_WEBHOOK_INVALID"
        flash[:alert] = "Failed to fire webhook: You must first set a Webhook URL for this item. Use 'Update Webhook URL' first."
      else
        flash[:alert] = "Plaid Error: #{e.message}"
      end
    rescue => e
      flash[:alert] = "Error: #{e.message}"
    end

    redirect_to mission_control_path
  end

  # PRD 0030: Update the Webhook URL for a Sandbox item
  def update_webhook_url
    item = PlaidItem.find_by(id: params[:id])
    unless item
      flash[:alert] = "Item not found"
      return redirect_to mission_control_path
    end

    webhook_url = params[:webhook_url].presence || ENV["PLAID_REDIRECT_URI"]&.gsub("/plaid_oauth/callback", "/plaid/webhook") || "https://api.higroundsolutions.com/plaid/webhook"
    client = Rails.application.config.x.plaid_client

    begin
      request = Plaid::ItemWebhookUpdateRequest.new(
        access_token: item.access_token,
        webhook: webhook_url
      )
      client.item_webhook_update(request)
      
      flash[:notice] = "Webhook URL updated to #{webhook_url} for #{item.institution_name}."
    rescue => e
      flash[:alert] = "Error updating webhook: #{e.message}"
    end

    redirect_to mission_control_path
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

  # PRD 8.3: Cost Tracker page
  def costs
    # Current month
    @current_month = Date.today.beginning_of_month
    @current_year = @current_month.year
    @current_month_number = @current_month.month
    
    # Calculate current month totals
    @current_month_total = PlaidApiCall.monthly_total(@current_year, @current_month_number)
    @current_month_breakdown = PlaidApiCall.monthly_breakdown(@current_year, @current_month_number)
    @average_per_call = PlaidApiCall.average_per_call(@current_year, @current_month_number)
    
    # Previous month
    @previous_month = @current_month - 1.month
    @previous_year = @previous_month.year
    @previous_month_number = @previous_month.month
    @previous_month_total = PlaidApiCall.monthly_total(@previous_year, @previous_month_number)
    
    # PRD 8.6: Monthly summary
    @monthly_summary = PlaidApiCall.monthly_summary.limit(12)
    
    # Recent cost logs
    @recent_logs = PlaidApiCall.order(called_at: :desc).limit(20)
    
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

  # PRD 8.5: Export all API costs as CSV
  def export_costs
    require 'csv'
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['Date', 'Product', 'Endpoint', 'Calls', 'Cost ($)', 'Request ID']
      
      PlaidApiCall.order(called_at: :desc).find_each do |call|
        csv << [
          call.called_at.strftime('%Y-%m-%d %H:%M:%S'),
          call.product,
          call.endpoint,
          call.transaction_count,
          sprintf('%.2f', call.cost_cents / 100.0),
          call.request_id
        ]
      end
    end
    
    send_data csv_data, filename: "plaid_api_costs_#{Date.today}.csv", type: 'text/csv'
  end

  private

  # Helper method to extract error_code from Plaid::ApiError
  def extract_plaid_error_code(error)
    return nil unless error.respond_to?(:response_body)
    parsed = JSON.parse(error.response_body) rescue {}
    parsed["error_code"]
  end
end
