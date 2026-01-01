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

# --- SmartProxy model registry hook (RubyLLM) ---
#
# `ai-agents` uses `RubyLLM::Chat.new(model: <id>)` internally.
# RubyLLM validates model ids against its registry (models.json).
# For SmartProxy, we often want to send arbitrary model ids like `llama3.1:70b`.
# To avoid `RubyLLM::Models::ModelNotFoundError`, we register those ids at boot.
if defined?(RubyLLM)
  begin
    models = RubyLLM::Models.instance.instance_variable_get(:@models)
    provider_slug = "openai"

    base_models = [
      ENV.fetch("AI_DEFAULT_MODEL", "llama3.1:70b"),
      ENV.fetch("AI_DEV_MODEL", "llama3.1:8b")
    ]

    extra_models = ENV.fetch("AI_EXTRA_MODELS", "").split(",").map(&:strip).reject(&:empty?)
    (base_models + extra_models).uniq.each do |model_id|
      next if models.any? { |m| m.id == model_id }
      models << RubyLLM::Model::Info.default(model_id, provider_slug)
    end
  rescue StandardError => e
    Rails.logger&.warn("RubyLLM model registry hook failed: #{e.class}: #{e.message}")
  end
end
