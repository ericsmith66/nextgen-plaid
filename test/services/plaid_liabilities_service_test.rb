require "test_helper"
require "ostruct"

class PlaidLiabilitiesServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "service_test@example.com", password: "password123")
    @plaid_item = PlaidItem.create!(
      user: @user,
      item_id: "item_service_test",
      institution_name: "Test Bank",
      access_token: "tok_service",
      status: "good"
    )
    @account = Account.create!(plaid_item: @plaid_item, account_id: "test_credit_card_account", mask: "0000")
    @service = PlaidLiabilitiesService.new(@plaid_item)
  end

  test "fetch_and_sync_liabilities updates account with credit card data and full details" do
    # Mock Plaid response
    mock_response = mock_liabilities_response_with_credit_card

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        @service.fetch_and_sync_liabilities

        @account.reload
        assert_equal 19.99, @account.apr_percentage
        assert_equal 25.00, @account.min_payment_amount
        assert_equal Date.parse("2025-01-15"), @account.next_payment_due_date
        assert_equal false, @account.is_overdue
        assert_equal true, @account.debt_risk_flag, "debt_risk_flag should be true for APR 19.99% > 5%"
        
        # PRD 0060: Verify liability_details storage
        assert @account.liability_details.present?
        assert_equal 19.99, @account.liability_details["credit"]["aprs"].first["apr_percentage"]
      end
    end
  end

  test "fetch_and_sync_liabilities sets debt_risk_flag for high APR" do
    # Mock Plaid response with high APR
    mock_response = mock_liabilities_response_with_high_apr

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        @service.fetch_and_sync_liabilities

        @account.reload
        assert_equal 24.99, @account.apr_percentage
        assert @account.debt_risk_flag, "debt_risk_flag should be true for APR > 5%"
      end
    end
  end

  test "fetch_and_sync_liabilities sets debt_risk_flag for overdue account" do
    # Mock Plaid response with overdue status
    mock_response = mock_liabilities_response_with_overdue

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        @service.fetch_and_sync_liabilities

        @account.reload
        assert @account.is_overdue, "is_overdue should be true"
        assert @account.debt_risk_flag, "debt_risk_flag should be true for overdue account"
      end
    end
  end

  test "fetch_and_sync_liabilities handles student loan data" do
    mock_response = mock_liabilities_response_with_student_loan

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        @service.fetch_and_sync_liabilities

        @account.reload
        assert_equal 4.5, @account.apr_percentage
        assert_equal 200.00, @account.min_payment_amount
        assert_equal false, @account.debt_risk_flag
      end
    end
  end

  test "fetch_and_sync_liabilities handles mortgage data" do
    mock_response = mock_liabilities_response_with_mortgage

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        @service.fetch_and_sync_liabilities

        @account.reload
        assert_equal 3.75, @account.apr_percentage
        assert_equal 1500.00, @account.min_payment_amount
        assert_equal false, @account.debt_risk_flag
      end
    end
  end

  test "fetch_and_sync_liabilities handles nil fields gracefully" do
    mock_response = mock_liabilities_response_with_nils

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        @service.fetch_and_sync_liabilities

        @account.reload
        assert_nil @account.apr_percentage
        assert_nil @account.min_payment_amount
        assert_equal false, @account.debt_risk_flag
      end
    end
  end

  test "fetch_and_sync_liabilities logs API call" do
    mock_response = mock_liabilities_response_with_credit_card

    Plaid::LiabilitiesGetRequest.stub :new, ->(*) { Object.new } do
      Rails.application.config.x.plaid_client.stub :liabilities_get, mock_response do
        assert_difference 'PlaidApiCall.count', 1 do
          @service.fetch_and_sync_liabilities
        end

        api_call = PlaidApiCall.last
        assert_equal 'liabilities', api_call.product
        assert_equal '/liabilities/get', api_call.endpoint
      end
    end
  end

  private

  def mock_liabilities_response_with_credit_card
    credit_card = OpenStruct.new(
      account_id: "test_credit_card_account",
      aprs: [OpenStruct.new(apr_percentage: 19.99)],
      minimum_payment_amount: 25.00,
      next_payment_due_date: "2025-01-15",
      is_overdue: false
    )

    OpenStruct.new(
      request_id: "test_request_123",
      liabilities: OpenStruct.new(
        credit: [credit_card],
        student: nil,
        mortgage: nil
      )
    )
  end

  def mock_liabilities_response_with_high_apr
    credit_card = OpenStruct.new(
      account_id: "test_credit_card_account",
      aprs: [OpenStruct.new(apr_percentage: 24.99)],
      minimum_payment_amount: 50.00,
      next_payment_due_date: "2025-01-15",
      is_overdue: false
    )

    OpenStruct.new(
      request_id: "test_request_124",
      liabilities: OpenStruct.new(
        credit: [credit_card],
        student: nil,
        mortgage: nil
      )
    )
  end

  def mock_liabilities_response_with_overdue
    credit_card = OpenStruct.new(
      account_id: "test_credit_card_account",
      aprs: [OpenStruct.new(apr_percentage: 15.99)],
      minimum_payment_amount: 75.00,
      next_payment_due_date: "2024-12-01",
      is_overdue: true
    )

    OpenStruct.new(
      request_id: "test_request_125",
      liabilities: OpenStruct.new(
        credit: [credit_card],
        student: nil,
        mortgage: nil
      )
    )
  end

  def mock_liabilities_response_with_student_loan
    student_loan = OpenStruct.new(
      account_id: "test_credit_card_account",
      interest_rate_percentage: 4.5,
      minimum_payment_amount: 200.00,
      next_payment_due_date: "2025-02-01",
      is_overdue: false
    )

    OpenStruct.new(
      request_id: "test_request_126",
      liabilities: OpenStruct.new(
        credit: nil,
        student: [student_loan],
        mortgage: nil
      )
    )
  end

  def mock_liabilities_response_with_mortgage
    mortgage = OpenStruct.new(
      account_id: "test_credit_card_account",
      interest_rate: OpenStruct.new(percentage: 3.75),
      last_payment_amount: 1500.00,
      next_payment_due_date: "2025-01-01",
      is_overdue: false
    )

    OpenStruct.new(
      request_id: "test_request_127",
      liabilities: OpenStruct.new(
        credit: nil,
        student: nil,
        mortgage: [mortgage]
      )
    )
  end

  def mock_liabilities_response_with_nils
    credit_card = OpenStruct.new(
      account_id: "test_credit_card_account",
      aprs: nil,
      minimum_payment_amount: nil,
      next_payment_due_date: nil,
      is_overdue: nil
    )

    OpenStruct.new(
      request_id: "test_request_128",
      liabilities: OpenStruct.new(
        credit: [credit_card],
        student: nil,
        mortgage: nil
      )
    )
  end
end
