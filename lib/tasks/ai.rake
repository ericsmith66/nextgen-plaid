# frozen_string_literal: true

namespace :ai do
  desc "Run a minimal Agent-05 spike request through SAP -> Coordinator (usage: rake ai:run_request['prompt'])"
  task :run_request, [:prompt] => :environment do |_t, args|
    prompt = args[:prompt].to_s

    if Rails.env.production? && ENV["ALLOW_AI_RAKE"] != "true"
      abort "Refusing to run ai:run_request in production without ALLOW_AI_RAKE=true"
    end

    model = ENV["AI_MODEL"]

    result = AiWorkflowService.run(prompt: prompt, model: model)

    puts "correlation_id=#{result.context[:correlation_id]}"
    puts "ball_with=#{result.context[:ball_with]}"
    puts "output:\n#{result.output}"
  rescue AiWorkflowService::EscalateToHumanError => e
    warn "\n=== Escalate to human ==="
    warn e.message
    warn "========================\n"
    exit 1
  rescue AiWorkflowService::GuardrailError => e
    warn "GuardrailError: #{e.message}"
    exit 1
  end

  desc "Refresh SmartProxy model ids into RubyLLM registry (best-effort)"
  task refresh_models: :environment do
    Ai::SmartProxyModelRegistry.register_models!(logger: Rails.logger)
    puts "Registered RubyLLM models (count=#{RubyLLM::Models.instance.instance_variable_get(:@models).size})" if defined?(RubyLLM)
  end
end
