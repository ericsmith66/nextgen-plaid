require "test_helper"
require "ostruct"

class PlaidOauthServiceTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: "test@example.com", password: "password123")
    @original_plaid_client = Rails.application.config.x.plaid_client
  end

  teardown do
    Rails.application.config.x.plaid_client = @original_plaid_client
  end

  test "create_link_token returns success with valid link token" do
    link_token = "link-sandbox-test-token"

    plaid_client = Object.new
    plaid_client.define_singleton_method(:link_token_create) do |_request|
      OpenStruct.new(link_token: link_token)
    end
    Rails.application.config.x.plaid_client = plaid_client

    service = PlaidOauthService.new(@user)
    result = service.create_link_token

    assert result[:success]
    assert_equal link_token, result[:link_token]
  end

  test "create_link_token returns error on API failure" do
    plaid_client = Object.new
    plaid_client.define_singleton_method(:link_token_create) do |_request|
      raise StandardError, "Invalid request"
    end
    Rails.application.config.x.plaid_client = plaid_client

    service = PlaidOauthService.new(@user)
    result = service.create_link_token

    assert_not result[:success]
    assert result[:error].present?
  end

  test "exchange_token creates PlaidItem with all required fields" do
    public_token = "public-sandbox-test-token"
    access_token = "access-sandbox-test-token"
    item_id = "item_test_123"
    institution_id = "ins_109508"
    institution_name = "Chase"

    plaid_client = Object.new
    plaid_client.define_singleton_method(:item_public_token_exchange) do |_request|
      OpenStruct.new(access_token: access_token, item_id: item_id)
    end
    plaid_client.define_singleton_method(:item_get) do |_request|
      OpenStruct.new(item: OpenStruct.new(institution_id: institution_id))
    end
    plaid_client.define_singleton_method(:institutions_get_by_id) do |_request|
      OpenStruct.new(institution: OpenStruct.new(name: institution_name))
    end
    Rails.application.config.x.plaid_client = plaid_client

    service = PlaidOauthService.new(@user)

    result = nil

    SyncHoldingsJob.stub(:perform_later, true) do
      SyncTransactionsJob.stub(:perform_later, true) do
        SyncLiabilitiesJob.stub(:perform_later, true) do
          result = service.exchange_token(public_token)
        end
      end
    end

    assert result[:success]
    assert_not_nil result[:plaid_item]
    
    plaid_item = result[:plaid_item]
    assert_equal item_id, plaid_item.item_id
    assert_equal institution_id, plaid_item.institution_id
    assert_equal institution_name, plaid_item.institution_name
    assert_equal "good", plaid_item.status
    assert_equal @user.id, plaid_item.user_id
    
    # Verify encrypted access_token is stored
    assert_not_nil plaid_item.access_token_encrypted
    assert_equal access_token, plaid_item.access_token
  end

  test "exchange_token updates existing PlaidItem if item_id matches" do
    public_token = "public-sandbox-test-token"
    access_token = "access-sandbox-new-token"
    item_id = "item_existing_123"
    institution_id = "ins_109508"
    institution_name = "Chase"

    # Create existing PlaidItem
    existing_item = PlaidItem.create!(
      user: @user,
      item_id: item_id,
      institution_id: "ins_old",
      institution_name: "Old Bank",
      access_token: "old-token",
      status: "good"
    )

    plaid_client = Object.new
    plaid_client.define_singleton_method(:item_public_token_exchange) do |_request|
      OpenStruct.new(access_token: access_token, item_id: item_id)
    end
    plaid_client.define_singleton_method(:item_get) do |_request|
      OpenStruct.new(item: OpenStruct.new(institution_id: institution_id))
    end
    plaid_client.define_singleton_method(:institutions_get_by_id) do |_request|
      OpenStruct.new(institution: OpenStruct.new(name: institution_name))
    end
    Rails.application.config.x.plaid_client = plaid_client

    service = PlaidOauthService.new(@user)

    assert_no_difference "PlaidItem.count" do
      SyncHoldingsJob.stub(:perform_later, true) do
        SyncTransactionsJob.stub(:perform_later, true) do
          SyncLiabilitiesJob.stub(:perform_later, true) do
            result = service.exchange_token(public_token)
            assert result[:success]
          end
        end
      end
    end

    existing_item.reload
    assert_equal access_token, existing_item.access_token
    assert_equal institution_name, existing_item.institution_name
  end

  test "exchange_token returns error on API failure" do
    public_token = "public-sandbox-bad-token"

    plaid_client = Object.new
    plaid_client.define_singleton_method(:item_public_token_exchange) do |_request|
      raise StandardError, "Invalid public token"
    end
    Rails.application.config.x.plaid_client = plaid_client

    service = PlaidOauthService.new(@user)
    result = service.exchange_token(public_token)

    assert_not result[:success]
    assert result[:error].present?
  end

  test "fetch_institution_name returns Unknown Institution on API error" do
    institution_id = "ins_bad"

    plaid_client = Object.new
    plaid_client.define_singleton_method(:institutions_get_by_id) do |_request|
      raise StandardError, "Institution not found"
    end
    Rails.application.config.x.plaid_client = plaid_client

    service = PlaidOauthService.new(@user)

    # Access private method for testing
    institution_name = service.send(:fetch_institution_name, institution_id)

    assert_equal "Unknown Institution", institution_name
  end
end
