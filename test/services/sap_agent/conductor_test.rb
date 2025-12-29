require "test_helper"

class SapAgentConductorTest < ActiveSupport::TestCase
  setup do
    @task = "Decompose PRD"
  end

  test "routes sub-agents in order" do
    SapAgent.stub(:sub_agent_outliner, ->(state) { { status: "ok", state: state.merge(steps: (state[:steps] || []) + [ "outliner" ]) } }) do
      SapAgent.stub(:sub_agent_refiner, ->(state, iteration) { { status: "ok", state: state.merge(steps: (state[:steps] || []) + [ "refiner-#{iteration}" ]) } }) do
        SapAgent.stub(:sub_agent_reviewer, ->(state) { { status: "ok", state: state.merge(steps: (state[:steps] || []) + [ "reviewer" ], score: 90) } }) do
          SapAgent.stub(:log_conductor_event, true) do
            result = SapAgent.conductor(task: @task, refiner_iterations: 3, max_jobs: 5)

            assert_equal "completed", result[:status]
            assert_equal %w[outliner refiner-1 refiner-2 refiner-3 reviewer], result[:state][:steps]
            assert_equal 90, result[:state][:score]
          end
        end
      end
    end
  end

  test "aborts when max jobs exceeded" do
    SapAgent.stub(:log_conductor_event, true) do
      result = SapAgent.conductor(task: @task, refiner_iterations: 5, max_jobs: 5)

      assert_equal "aborted", result[:status]
      assert_equal "max_jobs_exceeded", result[:reason]
    end
  end

  test "circuit breaker trips after three failures and falls back" do
    SapAgent.stub(:sub_agent_outliner, ->(state) { { status: "ok", state: state } }) do
      SapAgent.stub(:sub_agent_refiner, ->(state, _iter) { { status: "error", state: state.merge(failures: (state[:failures] || 0) + 1) } }) do
        SapAgent.stub(:sub_agent_reviewer, ->(state) { { status: "ok", state: state } }) do
          SapAgent.stub(:log_conductor_event, true) do
            result = SapAgent.conductor(task: @task, refiner_iterations: 3, max_jobs: 5)

            assert_equal "fallback", result[:status]
            assert_equal "circuit_breaker", result[:reason]
          end
        end
      end
    end
  end

  test "preserves idempotency and correlation in state" do
    correlation_id = SecureRandom.uuid
    idempotency_uuid = SecureRandom.uuid

    SapAgent.stub(:sub_agent_outliner, ->(state) { { status: "ok", state: state } }) do
      SapAgent.stub(:sub_agent_refiner, ->(state, _iter) { { status: "ok", state: state } }) do
        SapAgent.stub(:sub_agent_reviewer, ->(state) { { status: "ok", state: state } }) do
          SapAgent.stub(:log_conductor_event, true) do
            result = SapAgent.conductor(task: @task, correlation_id: correlation_id, idempotency_uuid: idempotency_uuid, refiner_iterations: 1)

            assert_equal idempotency_uuid, result[:state][:idempotency_uuid]
            assert_equal correlation_id, result[:state][:correlation_id]
          end
        end
      end
    end
  end
end
