require "test_helper"

class TransactionEnricherTest < ActiveSupport::TestCase
  test "returns 0 when given empty array regardless of flag" do
    ClimateControl.modify PLAID_ENRICH_ENABLED: "false" do
      assert_equal 0, TransactionEnricher.call([])
    end
    ClimateControl.modify PLAID_ENRICH_ENABLED: "true" do
      assert_equal 0, TransactionEnricher.call([])
    end
  end
end
