Rails.application.routes.draw do
  devise_for :users

  # Authenticated users get dashboard FIRST
  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  # Public users get welcome SECOND
  root "welcome#index"

  # Explicit dashboard route (requires authentication)
  get "/dashboard", to: "dashboard#index"

  post "/plaid/link_token", to: "plaid#link_token"
  post "/plaid/exchange",   to: "plaid#exchange"

  # Mission Control (owner-only)
  get "/mission_control", to: "mission_control#index"
  post "/mission_control/nuke", to: "mission_control#nuke"
  post "/mission_control/sync_holdings_now", to: "mission_control#sync_holdings_now"
  post "/mission_control/sync_transactions_now", to: "mission_control#sync_transactions_now"
  post "/mission_control/sync_liabilities_now", to: "mission_control#sync_liabilities_now"
  post "/mission_control/relink/:id", to: "mission_control#relink", as: :mission_control_relink
  post "/mission_control/relink_success/:id", to: "mission_control#relink_success", as: :mission_control_relink_success
  get  "/mission_control/logs", to: "mission_control#logs", defaults: { format: :json }
end