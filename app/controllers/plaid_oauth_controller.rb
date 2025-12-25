class PlaidOauthController < ApplicationController
  before_action :authenticate_user!, only: [:initiate]
  skip_before_action :verify_authenticity_token, only: [:callback]

  def initiate
    service = PlaidOauthService.new(current_user)
    result = service.create_link_token

    if result[:success]
      render json: { link_token: result[:link_token] }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error "PlaidOauth#initiate failed: #{e.message}"
    render json: { error: "Failed to create link token" }, status: :internal_server_error
  end

  def callback
    public_token = params[:public_token]
    client_user_id = params[:client_user_id]

    unless public_token.present? && client_user_id.present?
      redirect_to root_path, alert: "OAuth failed: Missing required parameters"
      return
    end

    user = User.find_by(id: client_user_id)
    unless user
      redirect_to root_path, alert: "OAuth failed: Invalid user"
      return
    end

    # Log connection info
    Rails.logger.info "OAuth callback received for user: #{user.email} | Cloudflare: #{request.headers['CF-Ray'].present?}"

    service = PlaidOauthService.new(user)
    result = service.exchange_token(public_token)

    if result[:success]
      redirect_to root_path, notice: "Chase linked successfully"
    else
      redirect_to root_path, alert: "OAuth failed: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "PlaidOauth#callback failed: #{e.message}"
    redirect_to root_path, alert: "OAuth failed: An unexpected error occurred"
  end

  private

  def cloudflare_request?
    request.headers['CF-Ray'].present?
  end

  def cloudflare_client_ip
    request.headers['CF-Connecting-IP'] || request.remote_ip
  end
end
