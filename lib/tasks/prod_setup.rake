# lib/tasks/prod_setup.rake
desc "Production setup tasks"
namespace :prod_setup do
  desc "Production seed wrapper"
  task seed: :environment do
    abort "Not in production" unless Rails.env.production?
    Rake::Task["db:seed"].invoke
  end

  desc "Smoke test Plaid configuration"
  task smoke_plaid: :environment do
    env_name = ENV.fetch("PLAID_ENV", Rails.env.production? ? "production" : "sandbox")
    keys_present = ENV["PLAID_CLIENT_ID"].present? && ENV["PLAID_SECRET"].present?
    
    output = "PLAID SMOKE TEST | Env: #{env_name} | Keys present: #{keys_present} | request_id_stub: <none>"
    
    puts output
    Rails.logger.info output

    if Rails.env.production? || env_name == "production"
      puts "Skipping API call in production."
    else
      puts "Non-production: Optional sandbox ping could be added here."
    end
  end
end
