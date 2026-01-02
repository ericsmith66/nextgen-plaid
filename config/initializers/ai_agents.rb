# frozen_string_literal: true

# AI Agents SDK (chatwoot/ai-agents)
# Gem: ai-agents
# Require: agents

require "agents"
require Rails.root.join("app", "services", "agents", "registry")
require Rails.root.join("app", "services", "ai", "smart_proxy_model_registry")

Agents.logger = defined?(Rails) ? Rails.logger : nil

Agents.configure do |config|
  # SmartProxy is OpenAI-compatible at /v1/chat/completions.
  # We route all providers (Ollama/Grok/Claude) through SmartProxy by selecting the model.
  smart_proxy_port = ENV.fetch("SMART_PROXY_PORT", Rails.env.test? ? "3002" : "3001")
  config.openai_api_base = ENV.fetch("SMART_PROXY_OPENAI_BASE", "http://localhost:#{smart_proxy_port}/v1")

  # SmartProxy may validate Authorization; use PROXY_AUTH_TOKEN if present.
  config.openai_api_key = ENV["SMART_PROXY_API_KEY"] || ENV["PROXY_AUTH_TOKEN"] || "local-dev"

  # Default model: heavy by default, overrideable for dev/test.
  config.default_model = ENV.fetch("AI_DEFAULT_MODEL", "llama3.1:70b")

  # 70b can be slow.
  config.request_timeout = Integer(ENV.fetch("AI_REQUEST_TIMEOUT", "60"))

  config.debug = ENV["AI_DEBUG"] == "true"
end

# --- CWA tool execution gate ---
# Tools are dry-run by default. To allow actual command execution, a human must set:
#   AI_TOOLS_EXECUTE=true
# This is intentionally not a Rails config knob to keep the security boundary simple.

# Eager-load tool classes in production so `Agents::Tool` subclasses are available.
require Rails.root.join("app", "tools", "safe_shell_tool")
require Rails.root.join("app", "tools", "git_tool")
require Rails.root.join("app", "tools", "project_search_tool")
require Rails.root.join("app", "tools", "vc_tool")
require Rails.root.join("app", "tools", "code_analysis_tool")
require Rails.root.join("app", "tools", "task_breakdown_tool")
require Rails.root.join("app", "services", "agent_sandbox_runner")

# --- Global agent registration (PRD 0010) ---
#
# Register CWA (Code Writing Agent) once at boot, as a factory. Workflows can
# fetch it with `Agents::Registry.fetch(:cwa, model: ...)`.
Agents::Registry.register(:cwa) do |model: nil, instructions: nil|
  # Load persona instructions from YAML to keep runtime logic aligned with Agent-05.
  require "yaml"
  personas_path = Rails.root.join("knowledge_base", "personas.yml")
  personas = YAML.safe_load(File.read(personas_path))
  instructions ||= personas.fetch("intp").fetch("description")

  Agents::Agent.new(
    name: "CWA",
    instructions: instructions,
    model: model || Agents.configuration.default_model,
    handoff_agents: [],
    tools: [ GitTool.new, SafeShellTool.new, ProjectSearchTool.new, VcTool.new, CodeAnalysisTool.new ]
  )
end

# --- SmartProxy model registry hook (RubyLLM) ---
Ai::SmartProxyModelRegistry.register_models!(logger: Rails.logger)
