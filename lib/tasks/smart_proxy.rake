# frozen_string_literal: true

namespace :smart_proxy do
  desc "Run live smoke tests against a running SmartProxy instance (requires SMART_PROXY_LIVE_TEST=true)"
  task live_test: :environment do
    ENV["SMART_PROXY_LIVE_TEST"] ||= "true"
    sh "bin/rails test test/smoke/smart_proxy_live_test.rb"
  end
end
