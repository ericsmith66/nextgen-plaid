class SapRunChannel < ApplicationCable::Channel
  def subscribed
    correlation_id = params[:correlation_id].presence
    reject unless correlation_id
    stream_for correlation_id
  end
end
