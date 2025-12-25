require "test_helper"

class Agents::MonitorControllerTest < ActionDispatch::IntegrationTest
  setup do
    @authorized_user = User.create!(email: "ericsmith66@me.com", password: "password", password_confirmation: "password")
    @unauthorized_user = User.create!(email: "other@example.com", password: "password", password_confirmation: "password")
  end

  test "should get index if authorized" do
    sign_in @authorized_user, scope: :user
    get agents_monitor_path
    assert_response :success
  end

  test "should redirect if unauthorized" do
    sign_in @unauthorized_user, scope: :user
    get agents_monitor_path
    assert_redirected_to root_path
    assert_equal "Not authorized.", flash[:alert]
  end

  test "should redirect if not logged in" do
    get agents_monitor_path
    assert_redirected_to new_user_session_path
  end
end
