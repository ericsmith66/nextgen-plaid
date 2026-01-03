# frozen_string_literal: true

require "json"
require "yaml"
require "fileutils"
require "securerandom"
require "time"
require Rails.root.join("app", "services", "ai", "cwa_task_log_service")

class AiWorkflowService
  class GuardrailError < StandardError; end
  class EscalateToHumanError < GuardrailError; end

  DEFAULT_MAX_TURNS = 5

  # PRD 0050: resume a run from persisted artifacts when possible.
  def self.load_existing_context(correlation_id)
    run_path = Rails.root.join("agent_logs", "ai_workflow", correlation_id.to_s, "run.json")
    return nil unless File.exist?(run_path)

    payload = JSON.parse(File.read(run_path))
    ctx = payload["context"]
    return nil unless ctx.is_a?(Hash)

    ctx.symbolize_keys
  rescue StandardError
    nil
  end

  # PRD 0050: explicit helper to encapsulate the handoff payload schema.
  def self.handoff_to_cwa(context:, reason: nil)
    {
      correlation_id: context[:correlation_id],
      micro_tasks: context[:micro_tasks] || [],
      reason: reason,
      state: context[:state]
    }.compact
  end

  def self.finalize_hybrid_handoff!(result, artifacts:)
    current_agent = result.context[:current_agent] || result.context["current_agent"]
    state = result.context[:state] || result.context["state"]

    # If CWA was the last agent to speak and we didn't hit an explicit error state,
    # transition to awaiting human review.
    if current_agent.to_s == "CWA" && state.to_s == "in_progress"
      result.context[:state] = "awaiting_review"
      result.context[:ball_with] = "Human"
      artifacts.record_event(type: "awaiting_review", from: "CWA")

      artifacts.record_event(
        type: "draft_artifacts_available",
        message: "Review draft artifacts (logs, diffs, commits) before merging.",
        correlation_id: result.context[:correlation_id] || result.context["correlation_id"],
        run_dir: Rails.root.join("agent_logs", "ai_workflow", (result.context[:correlation_id] || result.context["correlation_id"]).to_s).to_s,
        sandbox_hint: Rails.root.join("tmp", "agent_sandbox").to_s
      )
    end

    if state.to_s == "escalated_to_human" || state.to_s == "blocked"
      result.context[:ball_with] = "Human"
    end

    result
  end

  def self.run(prompt:, correlation_id: SecureRandom.uuid, max_turns: DEFAULT_MAX_TURNS, model: nil)
    raise GuardrailError, "prompt must be present" if prompt.nil? || prompt.strip.empty?

    context = load_existing_context(correlation_id) || build_initial_context(correlation_id)
    artifacts = ArtifactWriter.new(correlation_id)

    # PRD 0050: log Junie deprecation routing.
    if prompt.to_s.match?(/\bjunie\b/i)
      artifacts.record_event(type: "junie_deprecation", message: "Deprecating Junie: Using CWA for task")
    end

    cwa_agent = Agents::Registry.fetch(:cwa, model: model)

    coordinator_agent = build_agent(
      name: "Coordinator",
      instructions: persona_instructions("coordinator"),
      model: model,
      handoff_agents: [ cwa_agent ]
    )

    sap_agent = build_agent(
      name: "SAP",
      instructions: persona_instructions("sap"),
      model: model,
      handoff_agents: [ coordinator_agent ]
    )

    headers = {
      "X-Request-ID" => correlation_id
    }

    runner = Agents::Runner.with_agents(sap_agent, coordinator_agent, cwa_agent)
    artifacts.attach_callbacks!(runner)

    # Diagnostic breadcrumbs to help debug provider/proxy configuration issues.
    begin
      cfg = if Agents.respond_to?(:config)
        Agents.config
      elsif Agents.respond_to?(:configuration)
        Agents.configuration
      end

      artifacts.record_event(
        type: "runtime_config",
        agents_openai_api_base: cfg&.respond_to?(:openai_api_base) ? cfg.openai_api_base : nil,
        agents_default_model: cfg&.respond_to?(:default_model) ? cfg.default_model : nil,
        agents_request_timeout: cfg&.respond_to?(:request_timeout) ? cfg.request_timeout : nil,
        rails_env: Rails.env,
        smart_proxy_port: ENV["SMART_PROXY_PORT"],
        smart_proxy_openai_base: ENV["SMART_PROXY_OPENAI_BASE"],
        proxy_auth_token_present: ENV["PROXY_AUTH_TOKEN"].present?,
        smart_proxy_api_key_present: ENV["SMART_PROXY_API_KEY"].present?
      )
    rescue StandardError
      # ignore diagnostics
    end

    # Encourage tool-based handoff (the gem will expose `handoff_to_*` as tools).
    handoff_instruction = <<~TEXT
      If this request requires coordination or assignment, call the tool `handoff_to_coordinator`.
      If the request is implementation/test/commit work, the Coordinator should call the tool `handoff_to_cwa`.
      Otherwise, answer directly.
    TEXT

    result = runner.run(
      "#{handoff_instruction}\n\nUser request:\n#{prompt}",
      context: context,
      max_turns: max_turns,
      headers: headers
    )

    # Normalize ownership tracking.
    current_agent = result.context[:current_agent] || result.context["current_agent"]
    result.context[:ball_with] = current_agent

    turn_count = result.context[:turn_count] || result.context["turn_count"]
    result.context[:turns_count] = turn_count

    artifacts.write_run_json(result)

    finalize_hybrid_handoff!(result, artifacts: artifacts)

    artifacts.write_run_json(result)

    result
  rescue StandardError => e
    # Best-effort event + run.json on failures.
    begin
      artifacts ||= ArtifactWriter.new(correlation_id)
      artifacts.write_error(e)
    rescue StandardError
      # ignore
    end
    raise
  end

  # Multi-turn feedback/resolution loop.
  #
  # Intended usage:
  # - Call with `feedback: nil` to get an initial response + enter `awaiting_feedback`.
  # - Call again with `feedback:` to continue and attempt to reach a terminal state.
  def self.resolve_feedback(
    prompt:,
    feedback: nil,
    correlation_id: SecureRandom.uuid,
    max_turns: DEFAULT_MAX_TURNS,
    model: nil,
    route: "dm"
  )
    raise GuardrailError, "prompt must be present" if prompt.nil? || prompt.strip.empty?

    context = load_existing_context(correlation_id) || build_initial_context(correlation_id)
    artifacts = ArtifactWriter.new(correlation_id)

    if prompt.to_s.match?(/\bjunie\b/i)
      artifacts.record_event(type: "junie_deprecation", message: "Deprecating Junie: Using CWA for task")
    end

    initial = run_once(
      prompt: "User request:\n#{prompt}",
      context: context,
      artifacts: artifacts,
      max_turns: max_turns,
      model: model
    )

    finalize_hybrid_handoff!(initial, artifacts: artifacts)

    if feedback.nil? || feedback.to_s.strip.empty?
      entry = {
        ts: Time.now.utc.iso8601,
        prompt: prompt,
        requested_by: "Coordinator"
      }
      context[:state] = "awaiting_feedback"
      context[:feedback_history] << entry

      initial.context[:state] = context[:state]
      initial.context[:feedback_history] = context[:feedback_history]

      artifacts.record_event(type: "feedback_requested", route: route, requested_by: "Coordinator")
      artifacts.write_run_json(initial)
      return initial
    end

    entry = {
      ts: Time.now.utc.iso8601,
      prompt: prompt,
      feedback: feedback.to_s
    }
    context[:feedback_history] << entry
    artifacts.record_event(type: "feedback_received", route: route)

    resolved = run_once(
      prompt: "Resolve: #{prompt}\n\nFeedback:\n#{feedback}",
      context: context,
      artifacts: artifacts,
      max_turns: max_turns,
      model: model
    )

    finalize_hybrid_handoff!(resolved, artifacts: artifacts)
    context[:state] = "resolved"
    resolved.context[:state] = context[:state]
    resolved.context[:feedback_history] = context[:feedback_history]
    artifacts.record_event(type: "resolution_complete", state: resolved.context[:state], route: route)
    artifacts.write_run_json(resolved)
    resolved
  rescue EscalateToHumanError => e
    begin
      artifacts ||= ArtifactWriter.new(correlation_id)
      context ||= build_initial_context(correlation_id)
      context[:state] = "escalated_to_human"
      artifacts.record_event(type: "escalate_to_human", reason: e.message, route: route)
      artifacts.write_run_payload(correlation_id: correlation_id, error: e.message, context: context)
    rescue StandardError
      # ignore
    end
    raise
  end

  def self.build_initial_context(correlation_id)
    {
      correlation_id: correlation_id,
      state: "in_progress",
      ball_with: "SAP",
      turns_count: 0,
      feedback_history: [],
      artifacts: [],
      micro_tasks: []
    }
  end

  def self.persona_instructions(key)
    personas_path = Rails.root.join("knowledge_base", "personas.yml")
    personas = YAML.safe_load(File.read(personas_path))
    persona = personas.fetch(key)
    persona.fetch("description")
  end

  def self.build_agent(name:, instructions:, model:, handoff_agents:, tools: [])
    Agents::Agent.new(
      name: name,
      instructions: instructions,
      model: model || Agents.configuration.default_model,
      handoff_agents: handoff_agents,
      tools: tools
    )
  end

  def self.run_once(prompt:, context:, artifacts:, max_turns:, model: nil)
    routing_decision = Ai::RoutingPolicy.call(
      prompt: prompt,
      research_requested: !!(context[:research_requested] || context["research_requested"])
    )

    chosen_model = model || routing_decision.model_id

    artifacts.record_event(
      type: "routing_decision",
      policy_version: routing_decision.policy_version,
      model_id: routing_decision.model_id,
      use_live_search: routing_decision.use_live_search,
      reason: routing_decision.reason,
      chosen_model: chosen_model
    )

    cwa_agent = Agents::Registry.fetch(:cwa, model: chosen_model)

    planner_agent = build_agent(
      name: "Planner",
      instructions: persona_instructions("planner"),
      model: chosen_model,
      handoff_agents: [ cwa_agent ],
      tools: [ TaskBreakdownTool.new ]
    )

    coordinator_agent = build_agent(
      name: "Coordinator",
      instructions: persona_instructions("coordinator"),
      model: chosen_model,
      handoff_agents: [ planner_agent ]
    )

    sap_agent = build_agent(
      name: "SAP",
      instructions: persona_instructions("sap"),
      model: chosen_model,
      handoff_agents: [ coordinator_agent ]
    )

    headers = {
      "X-Request-ID" => context[:correlation_id]
    }

    runner = Agents::Runner.with_agents(sap_agent, coordinator_agent, planner_agent, cwa_agent)
    artifacts.attach_callbacks!(runner)

    handoff_instruction = <<~TEXT
      If this request requires coordination or assignment, call the tool `handoff_to_coordinator`.
      For implementation work, the Coordinator must first call the tool `handoff_to_planner`.
      The Planner must generate micro-tasks by calling the tool `task_breakdown_tool` and storing results into `context[:micro_tasks]`.
      If the request is implementation/test/commit work, the Coordinator should call the tool `handoff_to_cwa`.
      Otherwise, answer directly.
    TEXT

    result = runner.run(
      "#{handoff_instruction}\n\n#{prompt}",
      context: context,
      max_turns: max_turns,
      headers: headers
    )

    normalize_context!(result)
    enforce_turn_guardrails!(result, max_turns: max_turns, artifacts: artifacts)
    result
  rescue Timeout::Error, Net::ReadTimeout, Net::OpenTimeout => e
    artifacts.record_event(type: "timeout", message: e.message)
    raise EscalateToHumanError, "request timed out"
  rescue StandardError => e
    # Some HTTP stacks raise their own timeout types; treat as escalation if it smells like a timeout.
    if e.class.name.to_s.include?("Timeout")
      artifacts.record_event(type: "timeout", message: e.message, error_class: e.class.name)
      raise EscalateToHumanError, "request timed out"
    end
    raise
  end

  def self.normalize_context!(result)
    current_agent = result.context[:current_agent] || result.context["current_agent"]
    result.context[:ball_with] = current_agent

    turn_count = result.context[:turn_count] || result.context["turn_count"]
    result.context[:turns_count] = turn_count
    result
  end

  def self.enforce_turn_guardrails!(result, max_turns:, artifacts:)
    turns = (result.context[:turns_count] || 0).to_i
    return if turns < max_turns

    result.context[:state] = "escalated_to_human"
    artifacts.record_event(type: "max_turns_exceeded", turns_count: turns, max_turns: max_turns)
    raise EscalateToHumanError, "max turns exceeded"
  end

  class ArtifactWriter
    def initialize(correlation_id)
      @correlation_id = correlation_id
      @cwa_task_log_service = Ai::CwaTaskLogService.new(correlation_id: correlation_id, artifact_writer: self)
    end

    def attach_callbacks!(runner)
      runner.on_run_start(&method(:on_run_start))
      runner.on_agent_thinking(&method(:on_agent_thinking))
      runner.on_agent_handoff(&method(:on_agent_handoff))
      runner.on_agent_complete(&method(:on_agent_complete))
      runner.on_run_complete(&method(:on_run_complete))
      runner.on_tool_start(&method(:on_tool_start))
      runner.on_tool_complete(&method(:on_tool_complete))
      runner
    end

    def record_event(payload)
      write_event(payload)
    end

    def write_run_json(result)
      write_json("run.json", {
        correlation_id: @correlation_id,
        output: result.output,
        error: result.error&.message,
        error_class: result.error&.class&.name,
        error_backtrace: result.error&.backtrace,
        context: result.context,
        usage: result.usage,
        cwa_log: @cwa_task_log_service&.snapshot,
        cwa_log_markdown: @cwa_task_log_service&.markdown
      })
    end

    def write_run_payload(payload)
      enriched = payload.merge(
        cwa_log: @cwa_task_log_service&.snapshot,
        cwa_log_markdown: @cwa_task_log_service&.markdown
      )
      write_json("run.json", enriched)
    end

    def write_error(error)
      write_event(
        type: "error",
        message: error.message,
        error_class: error.class.name,
        error_backtrace: error.backtrace
      )
      write_json("run.json", {
        correlation_id: @correlation_id,
        error: error.message,
        error_class: error.class.name,
        error_backtrace: error.backtrace
      })
    end

    private

    def base_dir
      Rails.root.join("agent_logs", "ai_workflow", @correlation_id)
    end

    def ensure_dir!
      FileUtils.mkdir_p(base_dir)
    end

    def events_path
      base_dir.join("events.ndjson")
    end

    def write_json(filename, payload)
      ensure_dir!
      File.write(base_dir.join(filename), JSON.pretty_generate(payload) + "\n")
    end

    def write_event(payload)
      ensure_dir!
      enriched = payload.merge(
        correlation_id: @correlation_id,
        ts: Time.now.utc.iso8601
      )
      File.open(events_path, "a") { |f| f.puts(enriched.to_json) }

      broadcast_event(enriched)
    end

    def broadcast_event(event)
      return unless defined?(Turbo::StreamsChannel)

      Turbo::StreamsChannel.broadcast_prepend_to(
        "ai_workflow_#{@correlation_id}",
        target: "ai_workflow_events",
        partial: "admin/ai_workflow/event",
        locals: { event: event }
      )
    rescue StandardError => e
      raise if Rails.env.test?
      Rails.logger&.warn("ai_workflow broadcast failed: #{e.class}: #{e.message}")
    end

    def on_run_start(agent_name, input, _context_wrapper)
      write_event(type: "run_start", agent: agent_name, input: input)
      @cwa_task_log_service.on_run_start(agent_name, input, _context_wrapper)
    end

    def on_agent_thinking(agent_name, input)
      write_event(type: "agent_thinking", agent: agent_name, input: input)
    end

    def on_agent_handoff(from_agent, to_agent, reason)
      write_event(type: "agent_handoff", from: from_agent, to: to_agent, reason: reason)
      @cwa_task_log_service.on_agent_handoff(from_agent, to_agent, reason)
    end

    def on_agent_complete(agent_name, result, error, _context_wrapper)
      write_event(
        type: "agent_complete",
        agent: agent_name,
        output: result&.output,
        error: error&.message,
        error_class: error&.class&.name,
        error_backtrace: error&.backtrace
      )
      @cwa_task_log_service.on_agent_complete(agent_name, result, error, _context_wrapper)
    end

    def on_run_complete(agent_name, result, _context_wrapper)
      write_event(type: "run_complete", agent: agent_name, output: result&.output)
      @cwa_task_log_service.on_run_complete(agent_name, result, _context_wrapper)
    end

    def on_tool_start(tool_name, args)
      write_event(type: "tool_start", tool: tool_name, args: args)
      @cwa_task_log_service.on_tool_start(tool_name, args)
    end

    def on_tool_complete(tool_name, result)
      write_event(type: "tool_complete", tool: tool_name, result: result)
      @cwa_task_log_service.on_tool_complete(tool_name, result)
    end
  end
end
