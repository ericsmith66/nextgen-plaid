Rails.application.routes.draw do
  devise_for :users

  # Authenticated users get dashboard FIRST
  authenticated :user do
    root "dashboard#index", as: :authenticated_root
  end

  # Public users get welcome SECOND
  root "welcome#index"

  post "/plaid/link_token", to: "plaid#link_token"
  post "/plaid/exchange",   to: "plaid#exchange"
end