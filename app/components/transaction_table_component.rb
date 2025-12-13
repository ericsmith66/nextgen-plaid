class TransactionTableComponent < ViewComponent::Base
  def initialize(transactions:)
    @transactions = transactions
  end
end
