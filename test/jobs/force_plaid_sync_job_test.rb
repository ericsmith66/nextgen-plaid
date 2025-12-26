require "test_helper"
require "ostruct"

class ForcePlaidSyncJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "force@example.com", password: "Password123", roles: "owner")
    @item = PlaidItem.create!(
      user: @user,
      item_id: "it_force",
      institution_name: "Force Bank",
      access_token: "tok_force",
      status: "good"
    )
  end

  test "initiates transactions refresh and enqueues sync job" do
    mock_response = OpenStruct.new(request_id: "req_123")
    
    with_stubbed_plaid_client(transactions_refresh: mock_response) do
      assert_enqueued_with(job: SyncTransactionsJob, args: [@item.id]) do
        ForcePlaidSyncJob.perform_now(@item.id, "transactions")
      end
    end

    @item.reload
    assert_not_nil @item.last_force_at
  end

  test "initiates holdings refresh and enqueues sync job" do
    mock_response = OpenStruct.new(request_id: "req_456")
    
    with_stubbed_plaid_client(investments_refresh: mock_response) do
      assert_enqueued_with(job: SyncHoldingsJob, args: [@item.id]) do
        ForcePlaidSyncJob.perform_now(@item.id, "holdings")
      end
    end

    @item.reload
    assert_not_nil @item.last_force_at
  end

  test "enqueues liabilities sync job" do
    assert_enqueued_with(job: SyncLiabilitiesJob, args: [@item.id]) do
      ForcePlaidSyncJob.perform_now(@item.id, "liabilities")
    end

    @item.reload
    assert_not_nil @item.last_force_at
  end

  test "enforces rate limit (max 1/day)" do
    @item.update!(last_force_at: 1.hour.ago)
    
    assert_no_enqueued_jobs do
      ForcePlaidSyncJob.perform_now(@item.id, "transactions")
    end

    assert_in_delta 1.hour.ago, @item.reload.last_force_at, 1.second
  end

  test "allows force sync after 24 hours" do
    @item.update!(last_force_at: 25.hours.ago)
    
    mock_response = OpenStruct.new(request_id: "req_789")
    with_stubbed_plaid_client(transactions_refresh: mock_response) do
      assert_enqueued_jobs 1 do
        ForcePlaidSyncJob.perform_now(@item.id, "transactions")
      end
    end

    assert @item.reload.last_force_at > 1.minute.ago
  end
end
