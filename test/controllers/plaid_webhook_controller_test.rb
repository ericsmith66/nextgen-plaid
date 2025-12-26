require "test_helper"

class PlaidWebhookControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "webhook@example.com", password: "Password!123")
    @item = PlaidItem.create!(
      user: @user,
      item_id: "item_webhook_test",
      institution_name: "Test Bank",
      access_token: "tok_webhook",
      status: "good"
    )
  end

  test "POST /plaid/webhook enqueues SyncTransactionsJob on SYNC_UPDATES_AVAILABLE" do
    payload = {
      "webhook_type" => "TRANSACTIONS",
      "webhook_code" => "SYNC_UPDATES_AVAILABLE",
      "item_id" => @item.item_id
    }

    assert_enqueued_with(job: SyncTransactionsJob, args: [@item.id]) do
      post "/plaid/webhook", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :success
    end

    @item.reload
    assert @item.last_webhook_at.present?
    
    log = WebhookLog.last
    assert_equal "TRANSACTIONS:SYNC_UPDATES_AVAILABLE", log.event_type
    assert_equal "success", log.status
    assert_equal @item.id, log.plaid_item_id
  end

  test "POST /plaid/webhook enqueues SyncHoldingsJob on HOLDINGS DEFAULT_UPDATE" do
    payload = {
      "webhook_type" => "HOLDINGS",
      "webhook_code" => "DEFAULT_UPDATE",
      "item_id" => @item.item_id
    }

    assert_enqueued_with(job: SyncHoldingsJob, args: [@item.id]) do
      post "/plaid/webhook", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :success
    end
  end

  test "POST /plaid/webhook enqueues SyncLiabilitiesJob on LIABILITIES DEFAULT_UPDATE" do
    payload = {
      "webhook_type" => "LIABILITIES",
      "webhook_code" => "DEFAULT_UPDATE",
      "item_id" => @item.item_id
    }

    assert_enqueued_with(job: SyncLiabilitiesJob, args: [@item.id]) do
      post "/plaid/webhook", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :success
    end
  end

  test "POST /plaid/webhook ignores unknown item_id gracefully" do
    payload = {
      "webhook_type" => "TRANSACTIONS",
      "webhook_code" => "SYNC_UPDATES_AVAILABLE",
      "item_id" => "unknown_item"
    }

    assert_no_enqueued_jobs do
      post "/plaid/webhook", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
      assert_response :success
      assert_equal "ignored", JSON.parse(@response.body)["status"]
    end
  end

  test "POST /plaid/webhook handles ITEM ERROR" do
    payload = {
      "webhook_type" => "ITEM",
      "webhook_code" => "ERROR",
      "item_id" => @item.item_id,
      "error" => {
        "error_code" => "ITEM_LOGIN_REQUIRED",
        "error_message" => "The login details of this item have changed"
      }
    }

    post "/plaid/webhook", params: payload.to_json, headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :success

    @item.reload
    assert_equal "needs_reauth", @item.status
    assert_match /login details/, @item.last_error
  end
end
