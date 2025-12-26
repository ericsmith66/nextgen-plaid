# lib/tasks/plaid.rake
namespace :plaid do
  desc "Fire a sandbox webhook for a specific item"
  # Usage: bin/rails plaid:fire_webhook[item_id,webhook_code]
  # Example: bin/rails plaid:fire_webhook[1,SYNC_UPDATES_AVAILABLE]
  task :fire_webhook, [:id, :webhook_code] => :environment do |_, args|
    item_id = args[:id]
    webhook_code = args[:webhook_code] || "SYNC_UPDATES_AVAILABLE"

    if item_id.blank?
      puts "Error: item_id is required."
      puts "Usage: bin/rails plaid:fire_webhook[id,webhook_code]"
      exit 1
    end

    item = PlaidItem.find_by(id: item_id)
    unless item
      puts "Error: PlaidItem with ID #{item_id} not found."
      exit 1
    end

    client = Rails.application.config.x.plaid_client
    
    begin
      request = Plaid::SandboxItemFireWebhookRequest.new(
        access_token: item.access_token,
        webhook_code: webhook_code
      )
      
      response = client.sandbox_item_fire_webhook(request)
      
      puts "Successfully fired sandbox webhook!"
      puts "Item: #{item.institution_name} (#{item.item_id})"
      puts "Webhook Code: #{webhook_code}"
      puts "Request ID: #{response.request_id}"
      puts "Plaid should ping your webhook URL soon."
    rescue Plaid::ApiError => e
      puts "Plaid API Error: #{e.message}"
      puts "Body: #{e.response_body}"
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  desc "Update the webhook URL for a specific item"
  # Usage: bin/rails plaid:update_webhook[item_id,webhook_url]
  # Example: bin/rails plaid:update_webhook[1,https://your-tunnel.ngrok-free.app/plaid/webhook]
  task :update_webhook, [:id, :url] => :environment do |_, args|
    item_id = args[:id]
    webhook_url = args[:url]

    if item_id.blank? || webhook_url.blank?
      puts "Error: item_id and url are required."
      puts "Usage: bin/rails plaid:update_webhook[id,url]"
      exit 1
    end

    item = PlaidItem.find_by(id: item_id)
    unless item
      puts "Error: PlaidItem with ID #{item_id} not found."
      exit 1
    end

    client = Rails.application.config.x.plaid_client
    
    begin
      request = Plaid::ItemWebhookUpdateRequest.new(
        access_token: item.access_token,
        webhook: webhook_url
      )
      
      response = client.item_webhook_update(request)
      
      puts "Successfully updated webhook URL!"
      puts "Item: #{item.institution_name} (#{item.item_id})"
      puts "New Webhook URL: #{webhook_url}"
      puts "Request ID: #{response.request_id}"
    rescue Plaid::ApiError => e
      puts "Plaid API Error: #{e.message}"
      puts "Body: #{e.response_body}"
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  desc "Force a full sync for a specific product"
  # Usage: bin/rails plaid:force_full_sync[item_id,product]
  # Products: transactions, holdings, liabilities
  task :force_full_sync, [:id, :product] => :environment do |_, args|
    item_id = args[:id]
    product = args[:product]

    if item_id.blank? || product.blank?
      puts "Error: item_id and product are required."
      puts "Usage: bin/rails plaid:force_full_sync[id,product]"
      exit 1
    end

    # PRD 0050: Logic handled by ForcePlaidSyncJob
    # Note: Rake tasks usually don't enforce rate limits unless asked, 
    # but the job does. We'll call the job perform_now for synchronous feedback.
    begin
      ForcePlaidSyncJob.perform_now(item_id, product)
      puts "Force sync initiated for item_id:#{item_id}, product:#{product}"
    rescue => e
      puts "Error: #{e.message}"
    end
  end

  desc "Backfill 730-day transaction history"
  # Usage: bin/rails plaid:backfill_history[item_id]
  task :backfill_history, [:id] => :environment do |_, args|
    item_id = args[:id]

    if item_id.blank?
      puts "Error: item_id is required."
      puts "Usage: bin/rails plaid:backfill_history[id]"
      exit 1
    end

    # PRD 0050: backfill_history triggers /transactions/refresh for 730-day history
    # This is equivalent to force_full_sync[id, transactions]
    begin
      ForcePlaidSyncJob.perform_now(item_id, "transactions")
      puts "History backfill initiated for item_id:#{item_id}"
    rescue => e
      puts "Error: #{e.message}"
    end
  end
end
