# Gemfile – nextgen-plaid (Ruby 3.3.10 + Rails 8.0.4 – FINAL)
source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.10"

gem "rails", "~> 8.0.4"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "jbuilder"

# Rails 8 modern stack (all fully compatible with Ruby 3.3.10)
gem "solid_cache"
gem "solid_queue"      # replaces Sidekiq (we’ll add Sidekiq only if we outgrow it)
gem "solid_cable"
gem "bootsnap", require: false
gem "thruster", require: false
gem "kamal", require: false
gem "tzinfo-data", platforms: %i[ windows jruby ]

# =============================================================================
# NextGen Core – what actually matters for $20–$50M families
# =============================================================================
gem "devise"                    # Authentication
gem "plaid", "~> 36.0"          # Official Plaid gem (Investments + OAuth)
gem "attr_encrypted",">4.0.0"            # Encrypt Plaid access_token in DB
gem "dotenv-rails"

# UI/UX Framework (PRD UI-1)
gem "tailwindcss-rails"         # Tailwind CSS for utility styling
gem "view_component"            # ViewComponent for modular Ruby views

# =============================================================================
# Development & Test
# =============================================================================
group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "pry-rails"
  gem "webmock"
  gem "vcr"
  gem "climate_control"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
gem "kaminari", "~> 1.2"
