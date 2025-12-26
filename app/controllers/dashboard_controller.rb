class DashboardController < ApplicationController
  before_action :authenticate_user!

  def index
    # Preload associations for efficient count queries
    @plaid_items = current_user.plaid_items.includes(:accounts, :holdings, :recurring_transactions)
  end
end
