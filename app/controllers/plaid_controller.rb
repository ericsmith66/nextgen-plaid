class PlaidController < ApplicationController
  before_action :authenticate_user!

  def link_token
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: current_user.id.to_s },
      client_name: "NextGen Wealth Advisor",
      products: ["investments", "transactions", "liabilities"],
      country_codes: ["US"],
      language: "en"
    )

    client = Rails.application.config.x.plaid_client
    response = client.link_token_create(request)
    render json: { link_token: response.link_token }
  end

  def exchange
    public_token = params[:public_token]

    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token)
    client = Rails.application.config.x.plaid_client
    exchange_response = client.item_public_token_exchange(exchange_request)

    PlaidItem.create!(
      user: current_user,
      item_id: exchange_response.item_id,
      institution_name: params[:institution_name] || "Sandbox Institution",
      access_token: exchange_response.access_token,   # ← CORRECT
      status: "good"
    )

    SyncHoldingsJob.perform_later(PlaidItem.last.id)

    render json: { status: "connected" }
  end
end