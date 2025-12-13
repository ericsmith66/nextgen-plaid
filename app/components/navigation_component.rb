# frozen_string_literal: true

class NavigationComponent < ViewComponent::Base
  def initialize(current_user:)
    @current_user = current_user
  end

  def admin?
    @current_user&.admin?
  end

  def authenticated?
    @current_user.present?
  end
end
