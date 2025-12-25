class QueueRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :solid_queue, reading: :solid_queue }
end
