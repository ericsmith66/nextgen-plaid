require "test_helper"

class MissionControlControllerTest < ActionDispatch::IntegrationTest
  setup do
    @owner = User.create!(email: "ericsmith66@me.com", password: "Password!123")
    @user  = User.create!(email: "user@example.com", password: "Password!123")
  end

  test "owner can access mission control" do
    login_as(@owner, scope: :user)
    get "/mission_control"
    assert_response :success
    assert_match "Mission Control", @response.body
  end

  test "non-owner is redirected with flash" do
    login_as(@user, scope: :user)
    get "/mission_control"
    assert_response :redirect
    assert_redirected_to authenticated_root_path
    get authenticated_root_path
    assert_response :success
    assert_match "not authorized", @response.body
  end

  test "table lists plaid items with counts" do
    login_as(@owner, scope: :user)

    # Create sample data
    item = PlaidItem.create!(user: @owner, item_id: "it_123", institution_name: "Test Bank", access_token: "tok", status: "good")
    a1 = item.accounts.create!(account_id: "acc_1")
    item.accounts.create!(account_id: "acc_2")
    a1.positions.create!(security_id: "sec_1")
    a1.positions.create!(security_id: "sec_2")

    get "/mission_control"
    assert_response :success
    body = @response.body
    assert_includes body, "Test Bank"
    assert_includes body, "it_123"
    # #Accounts should be 2; #Positions should be 2
    assert_includes body, ">2<"
  end
end
