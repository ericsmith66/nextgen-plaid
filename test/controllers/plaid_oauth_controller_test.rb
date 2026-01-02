require "test_helper"
require "ostruct"

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

    fake_service = Object.new
    fake_service.define_singleton_method(:create_link_token) do
      { success: true, link_token: link_token }
    end

    PlaidOauthService.stub(:new, fake_service) do
      get plaid_oauth_initiate_url
    end
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal link_token, json_response["link_token"]
  end

  test "initiate returns error JSON on service failure" do
    login_as @user, scope: :user

    fake_service = Object.new
    fake_service.define_singleton_method(:create_link_token) do
      { success: false, error: "Invalid request" }
    end

    PlaidOauthService.stub(:new, fake_service) do
      get plaid_oauth_initiate_url
    end
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

    user = @user

    fake_service = Object.new
    fake_service.define_singleton_method(:exchange_token) do |_public_token|
      plaid_item = PlaidItem.create!(
        user: user,
        item_id: item_id,
        institution_id: institution_id,
        institution_name: institution_name,
        access_token: access_token,
        status: "good"
      )

      { success: true, plaid_item: plaid_item }
    end

    assert_difference "PlaidItem.count", 1 do
      PlaidOauthService.stub(:new, fake_service) do
        get plaid_oauth_callback_url, params: { public_token: public_token, client_user_id: @user.id }
      end
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

    fake_service = Object.new
    fake_service.define_singleton_method(:exchange_token) do |_token|
      { success: false, error: "Invalid public token" }
    end

    assert_no_difference "PlaidItem.count" do
      PlaidOauthService.stub(:new, fake_service) do
        get plaid_oauth_callback_url, params: { public_token: public_token, client_user_id: @user.id }
      end
    end

    assert_redirected_to root_path
    assert flash[:alert].include?("OAuth failed")
  end

  test "callback does not create invalid PlaidItem records on error" do
    public_token = "public-sandbox-bad-token"

    fake_service = Object.new
    fake_service.define_singleton_method(:exchange_token) do |_token|
      { success: false, error: "Invalid public token" }
    end

    initial_count = PlaidItem.count

    PlaidOauthService.stub(:new, fake_service) do
      get plaid_oauth_callback_url, params: { public_token: public_token, client_user_id: @user.id }
    end

    assert_equal initial_count, PlaidItem.count
    assert_redirected_to root_path
  end
end
