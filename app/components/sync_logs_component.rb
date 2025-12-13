# frozen_string_literal: true

class SyncLogsComponent < ViewComponent::Base
  def initialize(sync_logs:)
    @sync_logs = sync_logs
  end
end
