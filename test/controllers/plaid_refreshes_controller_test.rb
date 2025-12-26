require "test_helper"

class PlaidRefreshesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "owner_refresh@example.com", password: "Password123", roles: "owner")
    @user = User.create!(email: "user_refresh@example.com", password: "Password123", roles: "parent")
    @item = PlaidItem.create!(
      user: @owner,
      item_id: "it_refresh",
      institution_name: "Test Bank",
      access_token: "tok_refresh",
      status: "good"
    )
  end

  test "owner can trigger force refresh" do
    login_as @owner, scope: :user
    
    assert_enqueued_with(job: ForcePlaidSyncJob, args: [@item.id, "transactions"]) do
      post plaid_item_refresh_path(@item, product: "transactions")
    end

    assert_redirected_to mission_control_path
    assert_equal "Enqueued force refresh for transactions on Test Bank.", flash[:notice]
  end

  test "non-owner cannot trigger force refresh" do
    login_as @user, scope: :user
    
    assert_no_enqueued_jobs(only: ForcePlaidSyncJob) do
      post plaid_item_refresh_path(@item, product: "transactions")
    end

    assert_redirected_to authenticated_root_path
    assert_equal "Unauthorized", flash[:alert]
  end

  test "enforces rate limit in controller" do
    @item.update!(last_force_at: 1.hour.ago)
    login_as @owner, scope: :user

    assert_no_enqueued_jobs(only: ForcePlaidSyncJob) do
      post plaid_item_refresh_path(@item, product: "transactions")
    end

    assert_redirected_to mission_control_path
    assert_includes flash[:alert], "Rate limit hit"
  end
end
