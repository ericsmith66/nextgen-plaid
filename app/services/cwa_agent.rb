class CwaAgent
  ITERATION_LIMIT = 3

  def process_prd(task_id, user_id, prd_content)
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CWA",
      action: "CODE_GEN_START",
      details: "Starting code generation for PRD (limit: #{ITERATION_LIMIT})"
    )

    # Initial logic: Generate code plan
    # In a real run, this would call Ollama and write to tmp/agent_sandbox
    # For now, we simulate the handover to CSO
    
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CWA",
      action: "CODE_GEN_SUCCESS",
      details: "Generated code in sandbox. Requesting security evaluation."
    )

    AgentQueueJob.set(queue: :cwa_to_cso).perform_later(task_id, {
      commands: ["ls", "rails db:migrate"],
      user_id: user_id
    })
  rescue => e
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CWA",
      action: "CODE_GEN_FAILURE",
      details: e.message
    )
    raise e
  end

  def handle_security_feedback(task_id, user_id, evaluation)
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CWA",
      action: evaluation["approved"] ? "SECURITY_APPROVED" : "SECURITY_DENIED",
      details: "Received feedback: #{evaluation['reason']}"
    )

    if evaluation["approved"]
      # Proceed with execution (POC: log it)
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "CWA",
        action: "EXECUTE_SUCCESS",
        details: "Executed approved commands in sandbox."
      )
    else
      # Increment iteration and retry or halt
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "CWA",
        action: "REVISE_START",
        details: "Revising code based on security feedback."
      )
    end
  rescue => e
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CWA",
      action: "FEEDBACK_FAILURE",
      details: e.message
    )
    raise e
  end
end
