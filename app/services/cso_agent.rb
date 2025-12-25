class CsoAgent
  ESCALATION_THRESHOLD = 3

  def evaluate_commands(task_id, user_id, commands)
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CSO",
      action: "EVALUATE_START",
      details: "Evaluating commands: #{commands.join(', ')}"
    )

    prompt = <<~PROMPT
      You are the CSO Agent (Chief Security Officer).
      Evaluate the security risk of the following commands for a Rails 8 app.
      Commands: #{commands.join('; ')}
      
      Output your evaluation in JSON:
      {
        "approved": boolean,
        "reason": "string",
        "denial_count": integer
      }
    PROMPT

    # Call Ollama (CSO uses 405b in PRD, but we'll use 70b or mock here)
    eval_json = AiFinancialAdvisor.ask(prompt, model: "llama3.1:70b")
    
    # Placeholder for JSON parsing and escalation
    evaluation = begin
      JSON.parse(eval_json)
    rescue
      { "approved" => false, "reason" => "Failed to parse CSO response", "denial_count" => 1 }
    end

    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CSO",
      action: evaluation["approved"] ? "EVALUATE_APPROVE" : "EVALUATE_DENY",
      details: "Reason: #{evaluation['reason']}"
    )

    if !evaluation["approved"] && evaluation["denial_count"].to_i >= ESCALATION_THRESHOLD
      AgentLog.create!(
        task_id: task_id,
        user_id: user_id,
        persona: "CSO",
        action: "ESCALATE",
        details: "Denial threshold reached. Escalating to Admin."
      )
      # ActionMailer placeholder: AgentMailer.security_escalation(task_id).deliver_later
    end

    AgentQueueJob.set(queue: :cso_to_cwa).perform_later(task_id, {
      evaluation: evaluation,
      user_id: user_id
    })
  rescue => e
    AgentLog.create!(
      task_id: task_id,
      user_id: user_id,
      persona: "CSO",
      action: "EVALUATE_FAILURE",
      details: e.message
    )
    raise e
  end
end
