require "test_helper"

class PlaidControllerTest < ActionDispatch::IntegrationTest
  test "should get link_token" do
    get plaid_link_token_url
    assert_response :success
  end

  test "should get exchange" do
    get plaid_exchange_url
    assert_response :success
  end
end
