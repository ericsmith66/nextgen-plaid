class SapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info({ event: "sap.refresh.start" }.to_json)
    
    # 1. Refresh Inventory
    # We can invoke the rake task or just call a method if we refactor rake task to a service.
    # For simplicity, we'll use system call for now as the rake task is already tested.
    `bundle exec rake sap:inventory`
    
    # 2. Update Backlog (auto-status detection via git would happen here)
    # Since we don't have a full auto-detect from git method yet (it was planned in 0030)
    # we'll trigger the sync at least.
    SapAgent.sync_backlog
    
    # 3. Generate new snapshot
    FinancialSnapshotJob.perform_now
    
    Rails.logger.info({ event: "sap.refresh.completed" }.to_json)
  end
end