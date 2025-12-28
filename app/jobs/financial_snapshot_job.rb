class FinancialSnapshotJob < ApplicationJob
  queue_as :default

  SNAPSHOT_DIR = Rails.root.join('knowledge_base/snapshots')
  RETENTION_DAYS = 7

  def perform(user_id = nil)
    user_id ||= User.first&.id
    return unless user_id

    Rails.logger.info({ event: "financial_snapshot.start", user_id: user_id }.to_json)
    
    snapshot_data = {
      timestamp: Time.current,
      history: fetch_history,
      vision: fetch_vision,
      backlog: fetch_backlog,
      code_state: fetch_code_state
    }

    FileUtils.mkdir_p(SNAPSHOT_DIR)
    filename = "#{Time.current.strftime('%Y-%m-%d')}-project-snapshot.json"
    path = SNAPSHOT_DIR.join(filename)
    
    File.write(path, JSON.pretty_generate(snapshot_data))
    
    cleanup_old_snapshots
    
    Rails.logger.info({ event: "financial_snapshot.completed", user_id: user_id, path: path.to_s }.to_json)
  end

  private

  def fetch_history
    # Extract merged PRDs from git log
    `git log --grep='Merged PRD' --oneline`.lines.first(10).map do |line|
      match = line.match(/Merged PRD (\d+): (.*)/)
      match ? { id: match[1], title: match[2].strip } : { raw: line.strip }
    end
  rescue => e
    Rails.logger.warn({ event: "financial_snapshot.history_failed", error: e.message }.to_json)
    []
  end

  def fetch_vision
    mcp_path = Rails.root.join('knowledge_base/static_docs/MCP.md')
    return [] unless File.exist?(mcp_path)

    content = File.read(mcp_path)
    # Extract key paragraphs or sections
    content.scan(/^#+\s+.*\n(?:[^#].*\n)*/).first(5).map(&:strip)
  end

  def fetch_backlog
    backlog_path = Rails.root.join('knowledge_base/backlog.json')
    return [] unless File.exist?(backlog_path)

    JSON.parse(File.read(backlog_path)).first(20)
  rescue => e
    Rails.logger.warn({ event: "financial_snapshot.backlog_failed", error: e.message }.to_json)
    []
  end

  def fetch_code_state
    {
      schema: minify_schema,
      gemfile_summary: fetch_gemfile_summary
    }
  end

  def minify_schema
    schema_path = Rails.root.join('db/schema.rb')
    return "Schema not found" unless File.exist?(schema_path)

    content = File.read(schema_path)
    tables = []
    
    # Simple regex to extract tables and columns
    content.scan(/create_table\s+"(\w+)".*?do\s+\|t\|(.*?)\n\s+end/m).each do |table_name, columns_block|
      columns = columns_block.scan(/t\.(\w+)\s+"(\w+)"/).map { |type, name| "#{name}: #{type}" }
      tables << "Table: #{table_name} (#{columns.join(', ')})"
    end
    
    tables.join("\n")
  end

  def fetch_gemfile_summary
    gemfile_path = Rails.root.join('Gemfile')
    return "Gemfile not found" unless File.exist?(gemfile_path)

    File.read(gemfile_path).scan(/gem\s+"([^"]+)"/).flatten.join(", ")
  end

  def cleanup_old_snapshots
    Dir.glob(SNAPSHOT_DIR.join('*-project-snapshot.json')).each do |file|
      begin
        date = Date.parse(File.basename(file).split('-')[0..2].join('-'))
        if date < RETENTION_DAYS.days.ago.to_date
          File.delete(file)
          Rails.logger.info({ event: "financial_snapshot.cleanup", file: file }.to_json)
        end
      rescue ArgumentError
        next
      end
    end
  end
end
