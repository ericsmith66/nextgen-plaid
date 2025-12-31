class ApplicationController < ActionController::Base
  include Pundit::Authorization
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  protect_from_forgery with: :exception

  # This is the official Devise fix for Rails 7+ / 8
  # Without this, Devise login succeeds but warden.user is nil
  before_action :authenticate_user!, if: :devise_controller?
  before_action :set_environment_banner

  private

  def user_not_authorized
    if turbo_request?
      render json: { error: "Forbidden" }, status: :forbidden
    else
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(request.referrer || authenticated_root_path)
    end
  end

  def set_environment_banner
    return unless current_user
    env_label = Rails.env.production? ? "PRODUCTION" : "DEVELOPMENT"
    plaid_env = ENV["PLAID_ENV"]&.upcase || "SANDBOX"
    flash.now[:success] = "SECURE SESSION [#{env_label} | Plaid: #{plaid_env}]"
  end

  def require_owner
    owner_email = ENV["OWNER_EMAIL"].presence || "ericsmith66@me.com"
    unless current_user && current_user.email == owner_email
      flash[:alert] = "You are not authorized to access Mission Control."
      redirect_to authenticated_root_path
    end
  end

  def turbo_request?
    request.format.turbo_stream? || request.headers["Turbo-Frame"].present? || request.headers["Turbo-Visit"].present?
  end
end
