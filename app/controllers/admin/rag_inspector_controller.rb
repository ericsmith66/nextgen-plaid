class Admin::RagInspectorController < ApplicationController
  before_action :authenticate_user!
  before_action :require_owner

  def index
    @inventory = fetch_inventory
    @backlog = fetch_backlog
    @latest_snapshot = fetch_latest_snapshot
    @snapshots = fetch_all_snapshots
  end

  private

  def fetch_inventory
    path = Rails.root.join('knowledge_base/inventory.json')
    return [] unless File.exist?(path)
    JSON.parse(File.read(path))
  rescue => e
    Rails.logger.error("RAG Inspector: Failed to fetch inventory: #{e.message}")
    []
  end

  def fetch_backlog
    path = Rails.root.join('knowledge_base/backlog.json')
    return [] unless File.exist?(path)
    JSON.parse(File.read(path))
  rescue => e
    Rails.logger.error("RAG Inspector: Failed to fetch backlog: #{e.message}")
    []
  end

  def fetch_latest_snapshot
    path = Dir.glob(Rails.root.join('knowledge_base/snapshots/*-project-snapshot.json')).max
    return nil unless path && File.exist?(path)
    {
      name: File.basename(path),
      data: JSON.parse(File.read(path))
    }
  rescue => e
    Rails.logger.error("RAG Inspector: Failed to fetch latest snapshot: #{e.message}")
    nil
  end

  def fetch_all_snapshots
    Dir.glob(Rails.root.join('knowledge_base/snapshots/*-project-snapshot.json')).sort.reverse.map do |path|
      {
        name: File.basename(path),
        size: File.size(path),
        mtime: File.mtime(path)
      }
    end
  end
end
