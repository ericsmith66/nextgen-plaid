require "test_helper"

class SapAgentIteratePromptTest < ActiveSupport::TestCase
  setup do
    @task = "Refine PRD"
  end

  test "retries then stops when score crosses threshold" do
    outputs = [ "outline output", "refined output" ]
    scores = [ 75, 85 ]

    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, _model) { outputs.shift || "done" }) do
      SapAgent.stub(:score_output, ->(_out, _ctx) { scores.shift || 85 }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 100 }) do
          SapAgent.stub(:sleep, ->(_v) { true }) do
            result = SapAgent.iterate_prompt(task: @task)

            assert_equal "completed", result[:status]
            assert_equal 2, result[:iterations].size
            assert_equal 85, result[:score]
          end
        end
      end
    end
  end

  test "escalates model on low score" do
    scores = [ 60, 85 ]

    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, model) { "output-#{model}" }) do
      SapAgent.stub(:score_output, ->(_out, _ctx) { scores.shift }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 100 }) do
          SapAgent.stub(:sleep, ->(_v) { true }) do
            result = SapAgent.iterate_prompt(task: @task)

            assert_equal "completed", result[:status]
            assert_equal SapAgent::Config::MODEL_ESCALATE, result[:model_used]
            assert result[:iterations].any? { |iter| iter[:output].include?(SapAgent::Config::MODEL_ESCALATE.split("-").first) }
          end
        end
      end
    end
  end

  test "aborts when retries exhausted" do
    outputs = Array.new(5, "still refining")
    scores = Array.new(5, 75)

    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, _model) { outputs.shift }) do
      SapAgent.stub(:score_output, ->(_out, _ctx) { scores.shift }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 100 }) do
          SapAgent.stub(:sleep, ->(_v) { true }) do
            result = SapAgent.iterate_prompt(task: @task)

            assert_equal "aborted", result[:status]
            assert_equal "iteration_cap", result[:reason]
            assert_equal 3, result[:iterations].size
          end
        end
      end
    end
  end

  test "aborts on token budget exceed" do
    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, _model) { "long output" }) do
      SapAgent.stub(:estimate_tokens, ->(_text) { SapAgent::Config::TOKEN_BUDGET + 1 }) do
        result = SapAgent.iterate_prompt(task: @task)

        assert_equal "aborted", result[:status]
        assert_equal "token_budget_exceeded", result[:reason]
        assert result[:token_count] > SapAgent::Config::TOKEN_BUDGET
      end
    end
  end

  test "pause returns resume token and resumes with feedback" do
    pause_result = SapAgent.iterate_prompt(task: @task, pause: true)

    assert_equal "paused", pause_result[:status]
    assert pause_result[:resume_token].present?

    SapAgent.stub(:generate_iteration_output, ->(_ctx, _iter, _model) { "resumed output" }) do
      SapAgent.stub(:score_output, ->(_out, _ctx) { 90 }) do
        SapAgent.stub(:estimate_tokens, ->(_text) { 100 }) do
          SapAgent.stub(:sleep, ->(_v) { true }) do
            resumed = SapAgent.iterate_prompt(task: @task, resume_token: pause_result[:resume_token], human_feedback: "Add more details")

            assert_equal "completed", resumed[:status]
            assert_equal pause_result[:resume_token], resumed[:resume_token]
            assert_equal 1, resumed[:iterations].size
          end
        end
      end
    end
  end
end

# trailing newline