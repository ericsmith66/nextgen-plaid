class SapRun < ApplicationRecord
  belongs_to :user, optional: true

  enum :status, {
    pending: "pending",
    running: "running",
    paused: "paused",
    complete: "complete",
    failed: "failed",
    aborted: "aborted"
  }, suffix: true

  validates :correlation_id, presence: true, uniqueness: true

  scope :recent, -> { order(started_at: :desc).limit(50) }

  def redacted_user_label
    return "User-unknown" unless user_id
    digest = Digest::SHA256.hexdigest(user_id.to_s)[0..7]
    "User-#{digest}"
  end
end
