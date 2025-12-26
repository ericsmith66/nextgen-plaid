require "test_helper"
require "ostruct"

class SyncLiabilitiesJobTest < ActiveJob::TestCase
  def setup
    @user = User.create!(email: "liab_job@example.com", password: "password123")
    @item = PlaidItem.create!(
      user: @user,
      item_id: "item_liab_job",
      institution_name: "Test Bank",
      access_token: "tok_liab",
      status: "good"
    )
    @account = Account.create!(plaid_item: @item, account_id: "acc_liab_job", mask: "9999")
  end

  test "job delegates to PlaidLiabilitiesService and updates Account" do
    # Mock the service
    mock_service = Minitest::Mock.new
    mock_service.expect(:fetch_and_sync_liabilities, nil)

    PlaidLiabilitiesService.stub(:new, mock_service) do
      assert_difference "SyncLog.count", 2 do  # started + success
        SyncLiabilitiesJob.perform_now(@item.id)
      end
    end

    @item.reload
    assert @item.liabilities_synced_at.present?, "liabilities_synced_at should be set"

    log = SyncLog.where(plaid_item: @item, job_type: "liabilities", status: "success").last
    assert log.present?
    assert log.job_id.present?

    mock_service.verify
  end

  test "job updates account with liability data through service" do
    # Stub Plaid client for service
    mock_client = Minitest::Mock.new
    mock_response = mock_credit_card_response(@account.account_id)
    mock_client.expect(:liabilities_get, mock_response, [Plaid::LiabilitiesGetRequest])

    Rails.application.config.x.stub(:plaid_client, mock_client) do
      assert_difference "SyncLog.count", 2 do  # started + success
        SyncLiabilitiesJob.perform_now(@item.id)
      end
    end

    @account.reload
    assert_equal 18.99, @account.apr_percentage
    assert_equal 50.00, @account.min_payment_amount
    assert_not_nil @account.next_payment_due_date
    assert_equal false, @account.is_overdue
    assert @account.debt_risk_flag, "debt_risk_flag should be true for APR > 5%"

    log = SyncLog.where(plaid_item: @item, job_type: "liabilities", status: "success").last
    assert log.present?

    mock_client.verify
  end

  test "job logs failure on missing access_token" do
    @item.update!(access_token: nil)

    assert_difference "SyncLog.count", 1 do  # failure only
      SyncLiabilitiesJob.perform_now(@item.id)
    end

    log = SyncLog.where(plaid_item: @item, job_type: "liabilities", status: "failure").last
    assert log.present?
    assert_equal "missing access_token", log.error_message
  end

  private

  def mock_credit_card_response(account_id)
    credit_card = OpenStruct.new(
      account_id: account_id,
      aprs: [OpenStruct.new(apr_percentage: 18.99)],
      minimum_payment_amount: 50.00,
      next_payment_due_date: Date.today + 30,
      is_overdue: false
    )

    OpenStruct.new(
      request_id: "test_request_job",
      liabilities: OpenStruct.new(
        credit: [credit_card],
        student: nil,
        mortgage: nil
      )
    )
  end
end
