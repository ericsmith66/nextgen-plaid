class MissionControlController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner

  def index
    @plaid_items = PlaidItem.includes(:accounts, :positions).order(created_at: :desc)
  end

  def nuke
    # Delete in dependency order
    Position.delete_all
    Account.delete_all
    PlaidItem.delete_all

    flash[:notice] = "All Plaid data has been deleted."
    redirect_to mission_control_path
  end

  def sync_holdings_now
    count = 0
    PlaidItem.find_each do |item|
      SyncHoldingsJob.perform_later(item.id)
      count += 1
    end
    flash[:notice] = "Enqueued holdings sync for #{count} item(s)."
    redirect_to mission_control_path
  end

  def sync_transactions_now
    count = 0
    PlaidItem.find_each do |item|
      SyncTransactionsJob.perform_later(item.id)
      count += 1
    end
    flash[:notice] = "Enqueued transactions sync for #{count} item(s)."
    redirect_to mission_control_path
  end
end
