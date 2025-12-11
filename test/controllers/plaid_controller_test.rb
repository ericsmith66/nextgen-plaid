require "test_helper"
require "ostruct"

class PlaidControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "user@example.com", password: "Password!123")
    login_as(@user, scope: :user)
  end

  test "POST /plaid/link_token returns link token" do
    fake_response = OpenStruct.new(link_token: "link-sandbox-123")
    with_stubbed_plaid_client(link_token_create: fake_response) do
      assert_enqueued_jobs 0 do
        post "/plaid/link_token"
        assert_response :success
        body = JSON.parse(@response.body)
        assert_equal "link-sandbox-123", body["link_token"]
      end
    end
  end

  test "POST /plaid/exchange creates PlaidItem and enqueues sync job" do
    fake_exchange = OpenStruct.new(item_id: "item-123", access_token: "access-sandbox-abc")
    with_stubbed_plaid_client(item_public_token_exchange: fake_exchange) do
      assert_enqueued_with(job: SyncHoldingsJob) do
        post "/plaid/exchange", params: { public_token: "public-sandbox-xyz", institution_name: "Test Bank" }
        assert_response :success
      end
    end

    item = PlaidItem.last
    refute_nil item
    assert_equal @user.id, item.user_id
    assert_equal "item-123", item.item_id
    assert_equal "Test Bank", item.institution_name
    assert_equal "good", item.status
    assert item.access_token.present?
  end
end
