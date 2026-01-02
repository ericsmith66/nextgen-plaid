module SapAgent
  class Router
    def self.route(payload)
      query = payload[:query] || ""
      decision = Ai::RoutingPolicy.call(prompt: query, research_requested: !!payload[:research])
      log_decision(decision)
      decision.model_id
    end

    private

    def self.log_decision(decision)
      logger = Logger.new(Rails.root.join("agent_logs/sap.log"))
      logger.info(
        {
          event: "routing_decision",
          policy_version: decision.policy_version,
          model_id: decision.model_id,
          use_live_search: decision.use_live_search,
          reason: decision.reason
        }.to_json
      )
    end
  end
end
