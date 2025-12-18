class FinancialSnapshotJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    Rails.logger.info({ event: "financial_snapshot.enqueue", user_id: user_id }.to_json)
    # TODO: Implement snapshot aggregation; placeholder for CSV-5 acceptance
  end
end
