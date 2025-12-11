class SyncLog < ApplicationRecord
  belongs_to :plaid_item

  JOB_TYPES = %w[holdings transactions liabilities].freeze
  STATUSES  = %w[started success failure].freeze

  validates :job_type, presence: true, inclusion: { in: JOB_TYPES }
  validates :status, presence: true, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }
end
