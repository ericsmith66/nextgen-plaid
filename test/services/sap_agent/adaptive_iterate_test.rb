require "test_helper"

class SapAgentAdaptiveIterateTest < ActiveSupport::TestCase
  setup do
    @task = "Generate PRD"
  end

  test "retries with backoff then completes when score crosses threshold" do
    outputs = %w[draft refined final]
    scores = [ 75, 75, 85 ]
    sleep_calls = 0

    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, _model) { outputs.shift || "done" }) do
      SapAgent.stub(:score_output, ->(_out, _ctx) { scores.shift || 85 }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 100 }) do
          SapAgent.stub(:log_iterate_event, true) do
            SapAgent::TimeoutWrapper.stub(:with_timeout, ->(_s, &blk) { blk.call }) do
              SapAgent.stub(:sleep, ->(_v) { sleep_calls += 1 }) do
                result = SapAgent.adaptive_iterate(task: @task)

                assert_equal "completed", result[:status]
                assert_equal 3, result[:iterations].size
                assert_equal "final", result[:final_output]
                assert_equal 2, sleep_calls
              end
            end
          end
        end
      end
    end
  end

  test "escalates once on low score" do
    scores = [ 60, 85 ]

    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, model) { "out-#{model}" }) do
      SapAgent.stub(:score_output, ->(_out, _ctx) { scores.shift || 85 }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 100 }) do
          SapAgent.stub(:log_iterate_event, true) do
            SapAgent::TimeoutWrapper.stub(:with_timeout, ->(_s, &blk) { blk.call }) do
              SapAgent.stub(:sleep, ->(_v) { true }) do
                result = SapAgent.adaptive_iterate(task: @task)

                models = result[:iterations].map { |iter| iter[:model_used] }
                assert_includes models, "grok-4.1"
                refute_includes models, "claude-sonnet-4.5"
                assert_equal "completed", result[:status]
              end
            end
          end
        end
      end
    end
  end

  test "aborts when token budget exceeded" do
    SapAgent.stub(:generate_iteration_output, "long") do
      SapAgent.stub(:score_output, 50) do
        SapAgent.stub(:estimate_tokens, ->(_text) { SapAgent::Config::ADAPTIVE_TOKEN_BUDGET + 1 }) do
          SapAgent.stub(:log_iterate_event, true) do
            result = SapAgent.adaptive_iterate(task: @task)

            assert_equal "aborted", result[:status]
            assert_equal "token_budget_exceeded", result[:reason]
          end
        end
      end
    end
  end

  test "aborts at iteration cap with single escalation" do
    scores = Array.new(10, 60)

    SapAgent.stub(:generate_iteration_output, "out") do
      SapAgent.stub(:score_output, ->(_out, _ctx) { scores.shift || 60 }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 50 }) do
          SapAgent.stub(:log_iterate_event, true) do
            SapAgent::TimeoutWrapper.stub(:with_timeout, ->(_s, &blk) { blk.call }) do
              SapAgent.stub(:sleep, ->(_v) { true }) do
                result = SapAgent.adaptive_iterate(task: @task)

                assert_equal "aborted", result[:status]
                assert_equal "iteration_cap", result[:reason]
                models = result[:iterations].map { |iter| iter[:model_used] }.uniq
                assert models.count <= 2
              end
            end
          end
        end
      end
    end
  end
end
