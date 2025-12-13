class HoldingTableComponent < ViewComponent::Base
  def initialize(holdings:)
    @holdings = holdings
  end
end
