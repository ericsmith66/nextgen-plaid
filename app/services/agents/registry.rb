# frozen_string_literal: true

# Minimal app-level agent registry.
#
# The `ai-agents` gem does not provide a stable global registration API;
# PRD 0010 for Agent-06 expects a single CWA definition that can be reused
# across workflows. We keep a simple registry of factories (lambdas) that
# build `Agents::Agent` instances.
module Agents
  module Registry
    class UnknownAgent < StandardError; end

    @factories = {}

    class << self
      def register(key, factory = nil, &block)
        @factories[key.to_sym] = factory || block
      end

      def fetch(key, **kwargs)
        factory = @factories[key.to_sym]
        raise UnknownAgent, "unknown agent: #{key}" unless factory

        factory.call(**kwargs)
      end

      def keys
        @factories.keys
      end
    end
  end
end
