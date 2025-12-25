class AgentLog < ApplicationRecord
  belongs_to :user

  encrypts :details

  validates :task_id, :persona, :action, presence: true
end
