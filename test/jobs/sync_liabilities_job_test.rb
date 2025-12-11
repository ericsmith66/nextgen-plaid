require "test_helper"

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
    @account = Account.create!(plaid_item: @item, account_id: "acc_liab_job")
  end

  test "job creates liabilities on success" do
    # Stub Plaid client
    mock_client = Minitest::Mock.new
    mock_response = Minitest::Mock.new
    mock_liabilities = Minitest::Mock.new
    mock_credit = OpenStruct.new(
      account_id: @account.account_id,
      balances: OpenStruct.new(current: 1500.00),
      aprs: [OpenStruct.new(apr_percentage: 18.99)],
      last_payment_amount: 50.00,
      next_payment_due_date: Date.today + 30
    )

    # credit is called twice: once for if-check (truthy), once for select/iteration
    mock_liabilities.expect(:credit, [mock_credit])
    mock_liabilities.expect(:credit, [mock_credit])
    # student and mortgage return nil, so only called once for if-check (no iteration)
    mock_liabilities.expect(:student, nil)
    mock_liabilities.expect(:mortgage, nil)
    # response.liabilities is called multiple times to access the liabilities object
    mock_response.expect(:liabilities, mock_liabilities)
    mock_response.expect(:liabilities, mock_liabilities)
    mock_response.expect(:liabilities, mock_liabilities)
    mock_response.expect(:liabilities, mock_liabilities)
    mock_client.expect(:liabilities_get, mock_response, [Plaid::LiabilitiesGetRequest])

    Rails.application.config.x.stub(:plaid_client, mock_client) do
      assert_difference "Liability.count", 1 do
        assert_difference "SyncLog.count", 2 do  # started + success
          SyncLiabilitiesJob.perform_now(@item.id)
        end
      end
    end

    liability = Liability.last
    assert_equal "CREDIT_CARD", liability.liability_type
    assert_equal 1500.00, liability.current_balance

    log = SyncLog.where(plaid_item: @item, job_type: "liabilities", status: "success").last
    assert log.present?
    assert log.job_id.present?

    mock_client.verify
    mock_response.verify
    mock_liabilities.verify
  end

  test "job logs failure on missing access_token" do
    @item.update!(access_token: nil)

    assert_no_difference "Liability.count" do
      assert_difference "SyncLog.count", 1 do  # failure only
        SyncLiabilitiesJob.perform_now(@item.id)
      end
    end

    log = SyncLog.where(plaid_item: @item, job_type: "liabilities", status: "failure").last
    assert log.present?
    assert_equal "missing access_token", log.error_message
  end
end
