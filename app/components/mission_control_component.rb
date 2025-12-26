# frozen_string_literal: true

class MissionControlComponent < ViewComponent::Base
  def initialize(plaid_items:, transactions:, recurring_transactions:, accounts:, holdings:, sync_logs:, webhook_logs: [])
    @plaid_items = plaid_items
    @transactions = transactions
    @recurring_transactions = recurring_transactions
    @accounts = accounts
    @holdings = holdings
    @sync_logs = sync_logs
    @webhook_logs = webhook_logs
  end
end
