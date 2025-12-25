namespace :agents do
  desc 'Initiate POC Multi-Agent Task'
  task :poc_task, [:query, :user_id] => :environment do |_, args|
    query = args[:query] || 'Build a simple Plaid account list view'
    user_id = args[:user_id] || User.first&.id
    
    unless user_id
      puts 'ERROR: No user found. Please provide user_id or seed the database.'
      exit 1
    end

    task_id = SecureRandom.uuid
    puts "Initiating POC Task [#{task_id}] for User [#{user_id}]"
    puts "Query: #{query}"

    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: 'HUMAN',
      action: 'INITIATE',
      details: "User query: #{query}"
    )

    # In Phased implementation, we start with SAP
    SapAgent.new.decompose(task_id, user_id, query)
    puts "Phased Step: AGENT-02 (SAP Agent) has processed the query and enqueued for CWA."
    puts "Monitor the task here: http://localhost:80/agents/monitor"
  end

  desc "Monitor agent task in terminal"
  task :monitor, [:task_id] => :environment do |_, args|
    task_id = args[:task_id]
    puts "Monitoring Task [#{task_id}]... (Ctrl-C to stop)"
    
    loop do
      logs = AgentLog.where(task_id: task_id).order(created_at: :asc)
      if logs.any?
        logs.each do |log|
          puts "[#{log.created_at.strftime('%H:%M:%S')}] #{log.persona}: #{log.action} - #{log.details[0..100]}"
        end
        # Simple idempotency for POC monitor: just show last log and wait
        break if logs.last.action == 'EXECUTE_SUCCESS' || logs.last.action == 'ESCALATE'
      else
        puts "No logs found for #{task_id}."
      end
      sleep 5
    end
  end
end
