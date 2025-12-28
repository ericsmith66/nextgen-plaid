class PlaidWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  # PRD 0030: Webhook Controller Setup
  def create
    # Identify if it's a GitHub webhook
    if request.headers['X-GitHub-Event'].present?
      handle_github_webhook
      return
    end

    payload = JSON.parse(request.body.read)
    webhook_type = payload["webhook_type"]
    webhook_code = payload["webhook_code"]
    item_id = payload["item_id"]

    # Log incoming webhook
    Rails.logger.info({ event: "plaid.webhook.received", type: webhook_type, code: webhook_code, item_id: item_id }.to_json)

    # 2. Find Item
    item = PlaidItem.find_by(item_id: item_id)
    unless item
      # Plaid might send webhooks for items we just deleted
      Rails.logger.warn "Plaid webhook received for unknown item_id: #{item_id}"
      render json: { status: "ignored" }, status: :ok
      return
    end

    # 3. Process Events
    process_webhook_event(item, webhook_type, webhook_code, payload)

    # 4. Update last_webhook_at
    item.update_columns(last_webhook_at: Time.current)

    # Always return 200 OK
    render json: { status: "processed" }, status: :ok
  rescue => e
    Rails.logger.error "Plaid Webhook Error: #{e.message}"
    # Per Plaid requirements, always return 200 OK but log to DLQ
    log_webhook_failure(payload, e.message)
    render json: { status: "error_logged" }, status: :ok
  end

  private

  def process_webhook_event(item, type, code, payload)
    case type
    when "TRANSACTIONS"
      case code
      when "SYNC_UPDATES_AVAILABLE"
        SyncTransactionsJob.perform_later(item.id)
      when "INITIAL_UPDATE", "HISTORICAL_UPDATE", "DEFAULT_UPDATE"
        # These are legacy for /transactions/get, but good to trigger a sync anyway
        SyncTransactionsJob.perform_later(item.id)
      end
    when "HOLDINGS"
      case code
      when "DEFAULT_UPDATE"
        SyncHoldingsJob.perform_later(item.id)
      end
    when "INVESTMENTS_TRANSACTIONS"
      case code
      when "DEFAULT_UPDATE"
        # Investments transactions affect holdings/positions
        SyncHoldingsJob.perform_later(item.id)
        SyncTransactionsJob.perform_later(item.id)
      end
    when "LIABILITIES"
      case code
      when "DEFAULT_UPDATE"
        # PRD 0060: Enqueue liabilities sync on DEFAULT_UPDATE for liabilities accounts
        SyncLiabilitiesJob.perform_later(item.id)
      end
    when "ITEM"
      case code
      when "ERROR"
        error = payload["error"]
        item.update!(status: :needs_reauth, last_error: error["error_message"]) if error
      end
    end
    
    # Log successful processing
    WebhookLog.create!(
      plaid_item: item,
      event_type: "#{type}:#{code}",
      payload: payload,
      status: "success"
    )
  end

  def log_webhook_failure(payload, error_message)
    item_id = payload["item_id"]
    item = PlaidItem.find_by(item_id: item_id)
    
    WebhookLog.create!(
      plaid_item: item,
      event_type: "#{payload['webhook_type']}:#{payload['webhook_code']}",
      payload: payload,
      status: "failed",
      error_message: error_message
    )
  end

  def handle_github_webhook
    payload_body = request.body.read
    verify_github_signature(payload_body)
    
    payload = JSON.parse(payload_body)
    event = request.headers['X-GitHub-Event']
    
    if event == 'push' && payload['ref'] == 'refs/heads/main'
      files = (payload['commits'] || []).map { |c| c['added'] + c['modified'] }.flatten
      if files.any? { |f| f.start_with?('knowledge_base/') }
        Rails.logger.info("GitHub push to main detected with knowledge_base changes. Triggering refresh.")
        SapRefreshJob.perform_later
      end
    end
    
    render json: { status: "processed" }, status: :ok
  rescue => e
    Rails.logger.error "GitHub Webhook Error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def verify_github_signature(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET']
    return unless secret.present?

    signature = 'sha256=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), secret, payload_body)
    unless Rack::Utils.secure_compare(signature, request.headers['X-Hub-Signature-256'] || "")
      halt 401, "Signatures didn't match!"
    end
  end
end
