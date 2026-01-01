class SapRunsController < ApplicationController
  include ActionController::Live

  before_action :authenticate_user!
  before_action :set_correlation_id

  def status
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    data = streamer.summary
    events = streamer.events_after(params[:last_event_id])
    body = data.merge(events: events)

    render json: body

    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
    streamer.log_poll(latency_ms: latency, ok: true)
  rescue StandardError => e
    latency = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round rescue nil
    streamer.log_poll(latency_ms: latency || 0, ok: false, error: e)
    render json: { correlation_id: @correlation_id, error: e.message }, status: :internal_server_error
  end

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    last_id = params[:last_event_id]

    30.times do
      events = streamer.events_after(last_id)
      events.each do |event|
        response.stream.write("event: sap_run\n")
        response.stream.write("data: #{event.to_json}\n\n")
        last_id = event[:id]
      end

      response.stream.write("event: ping\n")
      response.stream.write("data: {\"correlation_id\":\"#{@correlation_id}\"}\n\n")
      sleep 3
    end
  rescue IOError
    # client disconnected
  ensure
    response.stream.close if response.stream.respond_to?(:close)
  end

  private

  def streamer
    @streamer ||= SapRunStream.new(correlation_id: @correlation_id)
  end

  def set_correlation_id
    @correlation_id = params[:id] || params[:correlation_id]
  end
end
