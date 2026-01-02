# frozen_string_literal: true

require "json"

class AiWorkflowSnapshot
  attr_reader :correlation_id, :run, :events

  def self.load_latest(correlation_id: nil, events_limit: 200)
    base_dir = Rails.root.join("agent_logs", "ai_workflow")
    return nil unless Dir.exist?(base_dir)

    run_dir = if correlation_id.present?
      base_dir.join(correlation_id)
    else
      latest_run_dir(base_dir)
    end
    return nil unless run_dir && Dir.exist?(run_dir)

    run_path = run_dir.join("run.json")
    return nil unless File.exist?(run_path)

    run = JSON.parse(File.read(run_path))

    events_path = run_dir.join("events.ndjson")
    events = if File.exist?(events_path)
      tail_ndjson(events_path, limit: events_limit)
    else
      []
    end

    new(
      correlation_id: run_dir.basename.to_s,
      run: run,
      events: events
    )
  rescue JSON::ParserError
    nil
  end

  def initialize(correlation_id:, run:, events:)
    @correlation_id = correlation_id
    @run = run
    @events = events
  end

  def context
    run["context"] || {}
  end

  def ball_with
    context["ball_with"]
  end

  def state
    context["state"]
  end

  def feedback_history
    Array(context["feedback_history"])
  end

  def started_at
    run["started_at"]
  end

  def finished_at
    run["finished_at"]
  end

  def status
    run["status"]
  end

  def error
    run["error"]
  end

  def output
    run["output"]
  end

  def self.latest_run_dir(base_dir)
    candidates = Dir.children(base_dir).map { |name| base_dir.join(name) }
      .select { |path| File.directory?(path) }
      .select { |path| File.exist?(path.join("run.json")) }

    candidates.max_by { |path| File.mtime(path.join("run.json")) }
  rescue Errno::ENOENT
    nil
  end

  def self.tail_ndjson(path, limit:)
    raw_lines = tail_lines(path, limit: limit)
    raw_lines.filter_map do |line|
      line = line.to_s.strip
      next if line.blank?
      JSON.parse(line)
    rescue JSON::ParserError
      { "raw" => line }
    end
  end

  # Efficient-ish tail that avoids slurping the full file for large logs.
  def self.tail_lines(path, limit:)
    return [] if limit <= 0

    lines = []
    buffer = +""
    chunk_size = 8 * 1024

    File.open(path, "rb") do |f|
      f.seek(0, IO::SEEK_END)
      pos = f.pos

      while pos.positive? && lines.length <= limit
        read_size = [ chunk_size, pos ].min
        pos -= read_size
        f.seek(pos, IO::SEEK_SET)
        buffer = f.read(read_size) + buffer

        parts = buffer.split("\n")
        buffer = parts.shift.to_s

        parts.reverse_each do |l|
          lines << l
          break if lines.length >= limit
        end
      end
    end

    lines.reverse
  end
end
