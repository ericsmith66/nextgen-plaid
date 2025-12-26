require "test_helper"

class DailyPlaidSyncJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    @user = User.create!(email: "daily@example.com", password: "Password123")
  end

  test "enqueues sync for item with nil last_webhook_at" do
    item = PlaidItem.create!(
      user: @user,
      item_id: "it_nil_webhook",
      institution_name: "Nil Bank",
      access_token: "tok_nil",
      status: "good",
      last_webhook_at: nil
    )

    assert_enqueued_with(job: SyncHoldingsJob, args: [item.id]) do
      assert_enqueued_with(job: SyncTransactionsJob, args: [item.id]) do
        assert_enqueued_with(job: SyncLiabilitiesJob, args: [item.id]) do
          DailyPlaidSyncJob.perform_now
        end
      end
    end
  end

  test "enqueues sync for overdue item (> 24h)" do
    item = PlaidItem.create!(
      user: @user,
      item_id: "it_old_webhook",
      institution_name: "Old Bank",
      access_token: "tok_old",
      status: "good",
      last_webhook_at: 25.hours.ago
    )

    assert_enqueued_with(job: SyncHoldingsJob, args: [item.id]) do
      DailyPlaidSyncJob.perform_now
    end
  end

  test "skips sync for fresh item (< 24h)" do
    item = PlaidItem.create!(
      user: @user,
      item_id: "it_fresh_webhook",
      institution_name: "Fresh Bank",
      access_token: "tok_fresh",
      status: "good",
      last_webhook_at: 1.hour.ago
    )

    assert_no_enqueued_jobs(only: SyncHoldingsJob) do
      DailyPlaidSyncJob.perform_now
    end
  end
end
