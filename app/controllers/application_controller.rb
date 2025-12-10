class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  # This is the official Devise fix for Rails 7+ / 8
  # Without this, Devise login succeeds but warden.user is nil
  before_action :authenticate_user!, if: :devise_controller?
end