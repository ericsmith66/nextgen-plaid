class SapProcessJob < ApplicationJob
  queue_as :default

  def perform(query_type, payload)
    SapAgent.process(query_type, payload)
  end
end
