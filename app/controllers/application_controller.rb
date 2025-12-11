class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # This is the official Devise fix for Rails 7+ / 8
  # Without this, Devise login succeeds but warden.user is nil
  before_action :authenticate_user!, if: :devise_controller?

  private

  def require_owner
    owner_email = ENV["OWNER_EMAIL"].presence || "ericsmith66@me.com"
    unless current_user && current_user.email == owner_email
      flash[:alert] = "You are not authorized to access Mission Control."
      redirect_to authenticated_root_path
    end
  end
end