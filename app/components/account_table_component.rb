class AccountTableComponent < ViewComponent::Base
  def initialize(accounts:)
    @accounts = accounts
  end
end
