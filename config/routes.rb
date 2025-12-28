Rails.application.routes.draw do
  post "/plaid_items/:id/refresh", to: "plaid_refreshes#create", as: :plaid_item_refresh
  namespace :agents do
    get "monitor", to: "monitor#index"
  end
  get "plaid_oauth/initiate"
  get "plaid_oauth/callback"
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
  get  "/plaid/sync_logs",  to: "plaid#sync_logs"
  post "/plaid/webhook",    to: "plaid_webhook#create"

  # Mission Control (owner-only)
  get "/mission_control", to: "mission_control#index"
  post "/mission_control/nuke", to: "mission_control#nuke"
  post "/mission_control/sync_holdings_now", to: "mission_control#sync_holdings_now"
  post "/mission_control/sync_transactions_now", to: "mission_control#sync_transactions_now"
  post "/mission_control/sync_liabilities_now", to: "mission_control#sync_liabilities_now"
  post "/mission_control/refresh_everything_now", to: "mission_control#refresh_everything_now"
  post "/mission_control/relink/:id", to: "mission_control#relink", as: :mission_control_relink
  post "/mission_control/relink_success/:id", to: "mission_control#relink_success", as: :mission_control_relink_success
  post "/mission_control/remove_item/:id", to: "mission_control#remove_item", as: :mission_control_remove_item
  post "/mission_control/fire_webhook/:id", to: "mission_control#fire_webhook", as: :mission_control_fire_webhook
  post "/mission_control/update_webhook_url/:id", to: "mission_control#update_webhook_url", as: :mission_control_update_webhook_url
  get  "/mission_control/logs", to: "mission_control#logs", defaults: { format: :json }
  get  "/mission_control/costs", to: "mission_control#costs"
  get  "/mission_control/costs/export.csv", to: "mission_control#export_costs", as: :export_mission_control_costs

  # Model inspection views
  resources :holdings
  resources :transactions
  resources :accounts

  # PRD UI-4: Admin namespace for user/account CRUD
  namespace :admin do
    resources :users
    resources :accounts
    get "rag_inspector", to: "rag_inspector#index"
  end
end