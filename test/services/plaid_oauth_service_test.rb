require "test_helper"
require "webmock/minitest"

class PlaidOauthServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", password: "password123")
    @service = PlaidOauthService.new(@user)
    @plaid_client = Rails.application.config.x.plaid_client
  end

  test "create_link_token returns success with valid link token" do
    link_token = "link-sandbox-test-token"
    
    # Stub the Plaid API call
    stub_request(:post, "https://sandbox.plaid.com/link/token/create")
      .to_return(
        status: 200,
        body: { link_token: link_token, expiration: "2024-01-01T00:00:00Z", request_id: "req123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @service.create_link_token

    assert result[:success]
    assert_equal link_token, result[:link_token]
  end

  test "create_link_token returns error on API failure" do
    # Stub API error
    stub_request(:post, "https://sandbox.plaid.com/link/token/create")
      .to_return(
        status: 400,
        body: { error_code: "INVALID_REQUEST", error_message: "Invalid request" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @service.create_link_token

    assert_not result[:success]
    assert result[:error].present?
  end

  test "exchange_token creates PlaidItem with all required fields" do
    public_token = "public-sandbox-test-token"
    access_token = "access-sandbox-test-token"
    item_id = "item_test_123"
    institution_id = "ins_109508"
    institution_name = "Chase"

    # Stub token exchange
    stub_request(:post, "https://sandbox.plaid.com/item/public_token/exchange")
      .with(body: hash_including({ public_token: public_token }))
      .to_return(
        status: 200,
        body: { access_token: access_token, item_id: item_id, request_id: "req123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub item/get
    stub_request(:post, "https://sandbox.plaid.com/item/get")
      .with(body: hash_including({ access_token: access_token }))
      .to_return(
        status: 200,
        body: {
          item: { item_id: item_id, institution_id: institution_id, webhook: nil },
          status: { investments: nil, transactions: nil },
          request_id: "req124"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub institutions/get_by_id
    stub_request(:post, "https://sandbox.plaid.com/institutions/get_by_id")
      .with(body: hash_including({ institution_id: institution_id }))
      .to_return(
        status: 200,
        body: {
          institution: { institution_id: institution_id, name: institution_name },
          request_id: "req125"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @service.exchange_token(public_token)

    assert result[:success]
    assert_not_nil result[:plaid_item]
    
    plaid_item = result[:plaid_item]
    assert_equal item_id, plaid_item.item_id
    assert_equal institution_id, plaid_item.institution_id
    assert_equal institution_name, plaid_item.institution_name
    assert_equal "good", plaid_item.status
    assert_equal @user.id, plaid_item.user_id
    
    # Verify encrypted access_token is stored
    assert_not_nil plaid_item.access_token_encrypted
    assert_equal access_token, plaid_item.access_token
  end

  test "exchange_token updates existing PlaidItem if item_id matches" do
    public_token = "public-sandbox-test-token"
    access_token = "access-sandbox-new-token"
    item_id = "item_existing_123"
    institution_id = "ins_109508"
    institution_name = "Chase"

    # Create existing PlaidItem
    existing_item = PlaidItem.create!(
      user: @user,
      item_id: item_id,
      institution_id: "ins_old",
      institution_name: "Old Bank",
      access_token: "old-token",
      status: "good"
    )

    # Stub token exchange
    stub_request(:post, "https://sandbox.plaid.com/item/public_token/exchange")
      .to_return(
        status: 200,
        body: { access_token: access_token, item_id: item_id, request_id: "req123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub item/get
    stub_request(:post, "https://sandbox.plaid.com/item/get")
      .to_return(
        status: 200,
        body: {
          item: { item_id: item_id, institution_id: institution_id, webhook: nil },
          status: { investments: nil, transactions: nil },
          request_id: "req124"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Stub institutions/get_by_id
    stub_request(:post, "https://sandbox.plaid.com/institutions/get_by_id")
      .to_return(
        status: 200,
        body: {
          institution: { institution_id: institution_id, name: institution_name },
          request_id: "req125"
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_no_difference "PlaidItem.count" do
      result = @service.exchange_token(public_token)
      assert result[:success]
    end

    existing_item.reload
    assert_equal access_token, existing_item.access_token
    assert_equal institution_name, existing_item.institution_name
  end

  test "exchange_token returns error on API failure" do
    public_token = "public-sandbox-bad-token"

    # Stub API error
    stub_request(:post, "https://sandbox.plaid.com/item/public_token/exchange")
      .to_return(
        status: 400,
        body: { error_code: "INVALID_PUBLIC_TOKEN", error_message: "Invalid public token" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @service.exchange_token(public_token)

    assert_not result[:success]
    assert result[:error].present?
  end

  test "fetch_institution_name returns Unknown Institution on API error" do
    institution_id = "ins_bad"

    # Stub API error
    stub_request(:post, "https://sandbox.plaid.com/institutions/get_by_id")
      .to_return(
        status: 404,
        body: { error_code: "INVALID_INSTITUTION", error_message: "Institution not found" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    # Access private method for testing
    institution_name = @service.send(:fetch_institution_name, institution_id)

    assert_equal "Unknown Institution", institution_name
  end
end
