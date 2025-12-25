Rails.application.config.to_prepare do
  SolidQueue::Record.connects_to database: { writing: :solid_queue, reading: :solid_queue }
end
