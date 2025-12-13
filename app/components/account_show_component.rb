class AccountShowComponent < ViewComponent::Base
  def initialize(account:)
    @account = account
  end
end
