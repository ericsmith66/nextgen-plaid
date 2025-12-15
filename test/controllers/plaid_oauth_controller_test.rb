require "test_helper"
require "webmock/minitest"

class PlaidOauthControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(email: "oauth@example.com", password: "password123")
  end

  # Initiate action tests
  test "initiate requires authentication" do
    get plaid_oauth_initiate_url
    assert_response :redirect
    assert_redirected_to new_user_session_path
  end

  test "initiate returns link_token JSON on success" do
    login_as @user, scope: :user
    link_token = "link-sandbox-test-token"

    stub_request(:post, "https://sandbox.plaid.com/link/token/create")
      .to_return(
        status: 200,
        body: { link_token: link_token, expiration: "2024-01-01T00:00:00Z", request_id: "req123" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get plaid_oauth_initiate_url
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal link_token, json_response["link_token"]
  end

  test "initiate returns error JSON on service failure" do
    login_as @user, scope: :user

    stub_request(:post, "https://sandbox.plaid.com/link/token/create")
      .to_return(
        status: 400,
        body: { error_code: "INVALID_REQUEST", error_message: "Invalid request" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    get plaid_oauth_initiate_url
    assert_response :unprocessable_entity

    json_response = JSON.parse(response.body)
    assert json_response["error"].present?
  end

  # Callback action tests
  test "callback redirects with success message and creates PlaidItem" do
    public_token = "public-sandbox-test-token"
    access_token = "access-sandbox-test-token"
    item_id = "item_test_123"
    institution_id = "ins_109508"
    institution_name = "Chase"

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

    assert_difference "PlaidItem.count", 1 do
      get plaid_oauth_callback_url, params: { public_token: public_token, client_user_id: @user.id }
    end

    assert_redirected_to root_path
    assert_equal "Chase linked successfully", flash[:notice]

    plaid_item = PlaidItem.last
    assert_equal item_id, plaid_item.item_id
    assert_equal @user.id, plaid_item.user_id
    assert_equal institution_name, plaid_item.institution_name
  end

  test "callback redirects with error when public_token missing" do
    get plaid_oauth_callback_url, params: { client_user_id: @user.id }

    assert_redirected_to root_path
    assert_equal "OAuth failed: Missing required parameters", flash[:alert]
  end

  test "callback redirects with error when client_user_id missing" do
    get plaid_oauth_callback_url, params: { public_token: "token123" }

    assert_redirected_to root_path
    assert_equal "OAuth failed: Missing required parameters", flash[:alert]
  end

  test "callback redirects with error when user not found" do
    get plaid_oauth_callback_url, params: { public_token: "token123", client_user_id: 99999 }

    assert_redirected_to root_path
    assert_equal "OAuth failed: Invalid user", flash[:alert]
  end

  test "callback redirects with error on API failure" do
    public_token = "public-sandbox-bad-token"

    stub_request(:post, "https://sandbox.plaid.com/item/public_token/exchange")
      .to_return(
        status: 400,
        body: { error_code: "INVALID_PUBLIC_TOKEN", error_message: "Invalid public token" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_no_difference "PlaidItem.count" do
      get plaid_oauth_callback_url, params: { public_token: public_token, client_user_id: @user.id }
    end

    assert_redirected_to root_path
    assert flash[:alert].include?("OAuth failed")
  end

  test "callback does not create invalid PlaidItem records on error" do
    public_token = "public-sandbox-bad-token"

    stub_request(:post, "https://sandbox.plaid.com/item/public_token/exchange")
      .to_return(
        status: 400,
        body: { error_code: "INVALID_PUBLIC_TOKEN", error_message: "Invalid public token" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    initial_count = PlaidItem.count

    get plaid_oauth_callback_url, params: { public_token: public_token, client_user_id: @user.id }

    assert_equal initial_count, PlaidItem.count
    assert_redirected_to root_path
  end
end
