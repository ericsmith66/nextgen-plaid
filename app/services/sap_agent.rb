module SapAgent
  COMMAND_MAPPING = {
    'generate' => SapAgent::GenerateCommand,
    'qa' => SapAgent::QaCommand,
    'debug' => SapAgent::DebugCommand,
    'health' => SapAgent::HealthCommand
  }.freeze

  def self.process(query_type, payload)
    command_class = COMMAND_MAPPING[query_type.to_s]
    raise "Unknown query type: #{query_type}" unless command_class

    command_class.new(payload).execute
  end

  def self.sync_backlog
    # Load backlog.json as SSOT
    backlog_path = Rails.root.join('knowledge_base/backlog.json')
    todo_path = Rails.root.join('TODO.md')
    
    backlog = File.exist?(backlog_path) ? JSON.parse(File.read(backlog_path)) : []
    
    # Generate human-readable TODO.md from JSON
    todo_content = "# NextGen Plaid — TODO\n\n"
    
    done = backlog.select { |i| i['status'] == 'Completed' }
    todo = backlog.select { |i| i['status'] != 'Completed' }
    
    todo_content << "## Next\n"
    todo.each do |item|
      todo_content << "- [ ] #{item['title']} (#{item['id']}) - #{item['priority']}\n"
    end
    
    todo_content << "\n## Done ✅\n"
    done.each do |item|
      todo_content << "- #{item['title']} (#{item['id']})\n"
    end
    
    File.write(todo_path, todo_content)
    Rails.logger.info({ event: "sap.backlog.synced", todo_count: todo.size, done_count: done.size }.to_json)
  end

  def self.update_backlog(item_data)
    # logic to update or add to backlog.json
    SapAgent::BacklogStrategy.store!(item_data)
    sync_backlog
  end

  def self.prune_backlog
    backlog_path = Rails.root.join('knowledge_base/backlog.json')
    archive_path = Rails.root.join('knowledge_base/backlog_archive.json')
    return unless File.exist?(backlog_path)

    backlog = JSON.parse(File.read(backlog_path))
    archive = File.exist?(archive_path) ? JSON.parse(File.read(archive_path)) : []

    # YAGNI prune: Low priority, not completed, and stale (>30 days)
    # For now, we'll use a simpler heuristic as we don't have timestamps on all items yet
    stale_cutoff = 30.days.ago
    
    pruned = []
    kept = []

    backlog.each do |item|
      # Don't prune High priority
      if item['priority'] != 'High' && item['status'] != 'Completed'
        # Check if it should be pruned
        # Placeholder for real staleness check
        # if item['updated_at'] < stale_cutoff
        #   pruned << item
        # else
        #   kept << item
        # end
        kept << item # default to keep until we add timestamps
      else
        kept << item
      end
    end

    if pruned.any?
      archive += pruned
      File.write(backlog_path, JSON.pretty_generate(kept))
      File.write(archive_path, JSON.pretty_generate(archive))
      sync_backlog
      Rails.logger.info({ event: "sap.backlog.pruned", count: pruned.size }.to_json)
    end
  end

  # This needs to be a class method or we need a way to call it.
  # For backward compatibility, maybe we keep it as a module method.
  def self.decompose(task_id, user_id, query)
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: 'SAP',
      action: 'DECOMPOSE_START',
      details: "Starting decomposition for query: #{query}"
    )

    result = process('generate', { query: query, user_id: user_id })
    prd_content = result[:response]

    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: 'SAP',
      action: 'DECOMPOSE_SUCCESS',
      details: "Generated PRD: #{prd_content[0..200]}..."
    )

    AgentQueueJob.set(queue: :sap_to_cwa).perform_later(task_id, { 
      prd: prd_content,
      user_id: user_id
    })
  rescue => e
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: 'SAP',
      action: 'DECOMPOSE_FAILURE',
      details: e.message
    )
    raise e
  end
end
