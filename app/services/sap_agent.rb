class SapAgent
  def decompose(task_id, user_id, query)
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: 'SAP',
      action: 'DECOMPOSE_START',
      details: "Starting decomposition for query: #{query}"
    )

    prompt = <<~PROMPT
      You are the SAP Agent (Senior Architect and Product Manager).
      Decompose the following human query into a structured Markdown PRD for a Rails 8 developer.
      Query: #{query}
      
      Your output must be ONLY the Markdown PRD.
    PROMPT

    prd_content = AiFinancialAdvisor.ask(prompt, model: 'llama3.1:70b')

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
