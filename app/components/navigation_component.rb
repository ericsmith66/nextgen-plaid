# frozen_string_literal: true

class NavigationComponent < ViewComponent::Base
  def initialize(current_user:)
    @current_user = current_user
  end

  def admin?
    @current_user&.admin?
  end

  def owner?
    return false unless @current_user
    owner_email = ENV["OWNER_EMAIL"].presence || "ericsmith66@me.com"
    @current_user.email == owner_email
  end

  def authenticated?
    @current_user.present?
  end
end
