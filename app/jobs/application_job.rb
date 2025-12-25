class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  private

  def skip_non_prod!(item, job_type)
    Rails.logger.warn "Skipping production Plaid call in non-prod env for #{job_type} job"
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
