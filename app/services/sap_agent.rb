module SapAgent
  COMMAND_MAPPING = {
    'generate' => SapAgent::GenerateCommand,
    'qa' => SapAgent::QaCommand,
    'debug' => SapAgent::DebugCommand
  }.freeze

  def self.process(query_type, payload)
    command_class = COMMAND_MAPPING[query_type.to_s]
    raise "Unknown query type: #{query_type}" unless command_class

    command_class.new(payload).execute
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
