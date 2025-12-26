# app/services/plaid_oauth_service.rb
class PlaidOauthService
  def initialize(user)
    @user = user
    @plaid_client = Rails.application.config.x.plaid_client
  end

  def create_link_token
    request = Plaid::LinkTokenCreateRequest.new(
      user: { client_user_id: @user.id.to_s },
      client_name: "NextGen Plaid",
      products: %w[investments transactions liabilities],
      country_codes: ["US"],
      language: "en",
      redirect_uri: ENV["PLAID_REDIRECT_URI"],
      transactions: Plaid::LinkTokenTransactions.new(days_requested: 730)
    )

    response = @plaid_client.link_token_create(request)
    { success: true, link_token: response.link_token }
  rescue Plaid::ApiError => e
    Rails.logger.error "Plaid API error creating link token: #{e.message}"
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error "Error creating link token: #{e.message}"
    { success: false, error: "Failed to create link token" }
  end

  def exchange_token(public_token)
    # Exchange public token for access token
    exchange_request = Plaid::ItemPublicTokenExchangeRequest.new(public_token: public_token)
    exchange_response = @plaid_client.item_public_token_exchange(exchange_request)

    access_token = exchange_response.access_token
    item_id = exchange_response.item_id

    # Get institution details
    item_request = Plaid::ItemGetRequest.new(access_token: access_token)
    item_response = @plaid_client.item_get(item_request)

    institution_id = item_response.item.institution_id
    institution_name = fetch_institution_name(institution_id)

    # Create or update PlaidItem
    plaid_item = PlaidItem.find_or_initialize_by(item_id: item_id, user: @user)
    plaid_item.assign_attributes(
      access_token: access_token,
      institution_id: institution_id,
      institution_name: institution_name,
      status: "good"
    )

    if plaid_item.save
      { success: true, plaid_item: plaid_item }
    else
      Rails.logger.error "Failed to save PlaidItem: #{plaid_item.errors.full_messages.join(', ')}"
      { success: false, error: "Failed to save item" }
    end
  rescue Plaid::ApiError => e
    Rails.logger.error "Plaid API error exchanging token: #{e.message}"
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error "Error exchanging token: #{e.message}"
    { success: false, error: "Failed to exchange token" }
  end

  private

  def fetch_institution_name(institution_id)
    request = Plaid::InstitutionsGetByIdRequest.new(
      institution_id: institution_id,
      country_codes: ["US"]
    )
    response = @plaid_client.institutions_get_by_id(request)
    response.institution.name
  rescue Plaid::ApiError => e
    Rails.logger.error "Failed to fetch institution name: #{e.message}"
    "Unknown Institution"
  end
end
