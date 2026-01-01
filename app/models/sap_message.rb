class SapMessage < ApplicationRecord
  belongs_to :sap_run

  enum :role, {
    user: "user",
    assistant: "assistant"
  }, suffix: true

  validates :role, presence: true

  after_create_commit -> {
    broadcast_append_to(
      stream_name,
      target: "chat-stream",
      partial: "admin/sap_collaborate/message",
      locals: { message: self }
    )
  }

  after_update_commit -> {
    broadcast_replace_to(
      stream_name,
      partial: "admin/sap_collaborate/message",
      locals: { message: self }
    )
  }

  def stream_name
    "sap_run_#{sap_run_id}"
  end
end
