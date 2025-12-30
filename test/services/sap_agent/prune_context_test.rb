require "test_helper"

class SapAgentPruneContextTest < ActiveSupport::TestCase
  setup do
    @context = <<~CTX
      2025-11-01 | accounts | users
      2025-10-01 | old_data | drop_me
      critical schema line
    CTX
  end

  test "skips when under target tokens" do
    SapAgent.stub(:estimate_tokens, 3000) do
      SapAgent.stub(:log_conductor_event, true) do
        result = SapAgent.prune_context(context: @context)

        assert_equal "skipped", result[:status]
        assert_equal 3000, result[:token_count]
      end
    end
  end

  test "prunes by heuristic and respects min_keep" do
    token_counts = [ 5001, 2500 ]
    SapAgent.stub(:estimate_tokens, ->(*) { token_counts.shift || 2500 }) do
      SapAgent.stub(:ollama_relevance, ->(_chunk) { 1.0 }) do
        SapAgent.stub(:age_weight, ->(chunk) { chunk.include?("2025-10-01") ? 0.0 : 1.0 }) do
          SapAgent.stub(:log_conductor_event, true) do
            result = SapAgent.prune_context(context: @context)

            assert_equal "pruned", result[:status]
            assert result[:context].include?("accounts")
            refute result[:context].include?("old_data")
            assert result[:token_count] >= SapAgent::Config::PRUNE_MIN_KEEP_TOKENS
          end
        end
      end
    end
  end

  test "warns when prune would violate min_keep floor" do
    SapAgent.stub(:estimate_tokens, ->(*) { 5001 }) do
      SapAgent.stub(:prune_by_heuristic, "tiny") do
        SapAgent.stub(:log_conductor_event, true) do
          result = SapAgent.prune_context(context: @context, min_keep: 6000)

          assert_equal "warning", result[:status]
          assert_equal "min_keep_floor", result[:warning]
        end
      end
    end
  end

  test "returns full context on error" do
    SapAgent.stub(:estimate_tokens, ->(*) { raise "boom" }) do
      SapAgent.stub(:log_conductor_event, true) do
        result = SapAgent.prune_context(context: @context)

        assert_equal "error", result[:status]
        assert_equal @context, result[:context]
      end
    end
  end
end
