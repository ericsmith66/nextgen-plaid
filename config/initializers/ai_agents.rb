# frozen_string_literal: true

# AI Agents SDK (chatwoot/ai-agents)
# Gem: ai-agents
# Require: agents

require "agents"

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
