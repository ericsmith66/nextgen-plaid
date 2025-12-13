# frozen_string_literal: true

class MissionControlComponent < ViewComponent::Base
  def initialize(plaid_items:, transactions:, recurring_transactions:, accounts:, holdings:)
    @plaid_items = plaid_items
    @transactions = transactions
    @recurring_transactions = recurring_transactions
    @accounts = accounts
    @holdings = holdings
  end
end
