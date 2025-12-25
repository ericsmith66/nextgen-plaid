class PlaidController < ApplicationController
  before_action :authenticate_user!

  def link_token
    begin
      request = Plaid::LinkTokenCreateRequest.new(
        user: { client_user_id: current_user.id.to_s },
        client_name: "NextGen Wealth Advisor",
        products: ["investments", "transactions", "liabilities"],
        country_codes: ["US"],
        language: "en",
        redirect_uri: ENV["PLAID_REDIRECT_URI"]
      )

      client = Rails.application.config.x.plaid_client
      response = client.link_token_create(request)
      render json: { link_token: response.link_token }
    rescue Plaid::ApiError => e
      Rails.logger.error "Plaid Link Token Error: #{e.message} | Body: #{e.response_body}"
      render json: { error: e.message, code: "PLAID_ERROR" }, status: :unprocessable_entity
    rescue => e
      Rails.logger.error "Internal Link Token Error: #{e.message}"
      render json: { error: "Internal Server Error" }, status: :internal_server_error
    end
  end

  def exchange
    public_token = params[:public_token]

    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token)
    client = Rails.application.config.x.plaid_client
    exchange_response = client.item_public_token_exchange(exchange_request)

    item = PlaidItem.create!(
      user: current_user,
      item_id: exchange_response.item_id,
      institution_name: params[:institution_name] || "Sandbox Institution",
      access_token: exchange_response.access_token,   # ← CORRECT
      status: "good"
    )

    # PRD 5.1: Sync everything on connect (holdings, transactions, liabilities)
    SyncHoldingsJob.perform_later(item.id)
    SyncTransactionsJob.perform_later(item.id)
    SyncLiabilitiesJob.perform_later(item.id)

    render json: { status: "connected" }
  end

  def sync_logs
    @sync_logs = SyncLog.includes(:plaid_item).order(created_at: :desc).limit(100)
  end
end