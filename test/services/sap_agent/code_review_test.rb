require "test_helper"

class SapAgentCodeReviewTest < ActiveSupport::TestCase
  setup do
    @files = %w[
      app/models/user.rb
      app/models/account.rb
      app/services/foo_service.rb
      test/models/user_test.rb
      docs/readme.md
    ]

    @contents = {
      "app/models/user.rb" => "class User; API_KEY='secret'; end",
      "app/models/account.rb" => "class Account; end",
      "app/services/foo_service.rb" => "class FooService; end",
      "test/models/user_test.rb" => "require 'test_helper'"
    }
  end

  test "selects prioritized files and runs rubocop with issues capped" do
    offenses = Array.new(SapAgent::Config::OFFENSE_LIMIT + 5) do |i|
      { "offense" => "issue #{i}", "line" => i + 1 }
    end

    SapAgent.stub(:diff_files, @files) do
      SapAgent.stub(:fetch_contents, @contents) do
        SapAgent.stub(:run_rubocop, offenses) do
          output = SapAgent.code_review(branch: "main", task_id: "task-123", correlation_id: "corr-1")

          assert_equal SapAgent::Config::OFFENSE_LIMIT, output["issues"].size
          assert_includes output["recommendations"].first, "issue 0"
          assert_equal 1, output["issues"].first["line"]
        end
      end
    end
  end

  test "redacts secrets with denylist and preserves allowlist" do
    allowlist = [ "SAFE_TOKEN" ]
    denylist = [ "API_KEY" ]
    SapAgent::Redactor.stub(:load_lists, [ allowlist, denylist ]) do
      SapAgent.stub(:diff_files, @files) do
        SapAgent.stub(:fetch_contents, @contents) do
          SapAgent.stub(:run_rubocop, []) do
            output = SapAgent.code_review(branch: "main", task_id: "task-456", correlation_id: "corr-2")

            redacted_file = output["files"]["app/models/user.rb"]
            secret_hash = Digest::SHA256.hexdigest("API_KEY")

            refute_includes redacted_file, "API_KEY"
            assert_includes redacted_file, secret_hash
          end
        end
      end
    end
  end

  test "aborts when token budget exceeded" do
    big_contents = { "app/models/user.rb" => "a" * (SapAgent::Config::TOKEN_BUDGET * 10) }
    SapAgent.stub(:diff_files, [ "app/models/user.rb" ]) do
      SapAgent.stub(:fetch_contents, big_contents) do
        result = SapAgent.code_review(branch: "main", task_id: "task-789", correlation_id: "corr-3")

        assert_equal "Budget exceeded", result[:error]
        assert result[:token_count] > SapAgent::Config::TOKEN_BUDGET
      end
    end
  end
end
