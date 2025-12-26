require "test_helper"

class SnapshotTest < ActiveSupport::TestCase
  test "should save snapshot with data" do
    user = User.first || User.create!(email: "test@example.com", password: "password")
    snapshot = Snapshot.new(user: user, data: { balance: 1000 })
    assert snapshot.save
    assert_equal 1000, snapshot.data["balance"]
  end
end
