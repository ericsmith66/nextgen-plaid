class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  def should_skip_sync?
   # Only skip if we are trying to use PRODUCTION Plaid in a NON-PRODUCTION Rails environment.
   # We WANT to allow 'sandbox' or 'development' Plaid environments in any Rails environment.
   ENV["PLAID_ENV"] == "production" && !Rails.env.production?
   false
  end

  def skip_non_prod!(item, job_type)
    Rails.logger.warn "SECURITY GUARD: Skipping production Plaid call in #{Rails.env} environment for #{job_type} job"
    SyncLog.create!(
      plaid_item: item,
      job_type: job_type,
      status: "skipped",
      error_message: "Non-prod env guard: Rails.env=#{Rails.env}, PLAID_ENV=#{ENV['PLAID_ENV']}",
      job_id: self.job_id
    )
    true
  end

  def production_plaid?
    Rails.env.production? && ENV["PLAID_ENV"] == "production"
  end
end
