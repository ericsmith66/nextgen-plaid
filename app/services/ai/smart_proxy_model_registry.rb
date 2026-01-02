# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Ai
  class SmartProxyModelRegistry
    # Register SmartProxy model ids into the RubyLLM registry so `RubyLLM::Chat` accepts
    # ids like `llama3.1:70b`.
    #
    # Best-effort only: failures should not prevent boot.
    def self.register_models!(logger: nil)
      return unless defined?(RubyLLM)

      cfg = if Agents.respond_to?(:config)
        Agents.config
      elsif Agents.respond_to?(:configuration)
        Agents.configuration
      end

      models = RubyLLM::Models.instance.instance_variable_get(:@models)
      provider_slug = "openai"

      base_models = [
        ENV.fetch("AI_DEFAULT_MODEL", "llama3.1:70b"),
        ENV.fetch("AI_DEV_MODEL", "llama3.1:8b")
      ]

      extra_models = ENV.fetch("AI_EXTRA_MODELS", "").split(",").map(&:strip).reject(&:empty?)
      discovered_models = discover_models(cfg: cfg, logger: logger)

      (base_models + extra_models + discovered_models).uniq.each do |model_id|
        next if models.any? { |m| m.id == model_id }
        models << RubyLLM::Model::Info.default(model_id, provider_slug)
      end
    rescue StandardError => e
      logger&.warn("SmartProxy model registry hook failed: #{e.class}: #{e.message}")
    end

    def self.discover_models(cfg:, logger: nil)
      return [] unless cfg&.respond_to?(:openai_api_base)
      return [] if cfg.openai_api_base.to_s.empty?

      uri = URI.join(cfg.openai_api_base, "/models")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{cfg.openai_api_key}" if cfg.respond_to?(:openai_api_key) && cfg.openai_api_key
      res = http.request(req)
      return [] unless res.is_a?(Net::HTTPSuccess)

      parsed = JSON.parse(res.body)
      Array(parsed["data"]).map { |m| m["id"] }.compact
    rescue StandardError => e
      logger&.info("SmartProxy /v1/models discovery skipped: #{e.class}: #{e.message}")
      []
    end

    private_class_method :discover_models
  end
end
