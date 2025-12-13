class TransactionShowComponent < ViewComponent::Base
  def initialize(transaction:)
    @transaction = transaction
  end
end
