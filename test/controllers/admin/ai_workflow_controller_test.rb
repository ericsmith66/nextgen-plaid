require "test_helper"

class Admin::AiWorkflowControllerTest < ActionDispatch::IntegrationTest
  def setup
    super
    @admin = User.create!(
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      roles: "admin"
    )

    @user = User.create!(
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123",
      roles: "parent"
    )
  end

  def test_requires_admin
    login_as @user, scope: :user

    AiWorkflowSnapshot.stub(:load_latest, nil) do
      get admin_ai_workflow_path
      assert_response :forbidden
    end
  end

  def test_renders_empty_state_for_admin_when_no_artifacts
    login_as @admin, scope: :user

    AiWorkflowSnapshot.stub(:load_latest, nil) do
      get admin_ai_workflow_path
      assert_response :success
      assert_includes @response.body, "No active workflow artifacts found"
    end
  end
end
