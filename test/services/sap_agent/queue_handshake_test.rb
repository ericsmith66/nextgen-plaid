require "test_helper"

class SapAgentQueueHandshakeTest < ActiveSupport::TestCase
  setup do
    @artifact = { result: "ok" }
    @task_summary = "Store iteration artifact"
    @task_id = "0040"
  end

  test "commits artifact with formatted message" do
    SapAgent.stub(:git_log_for_uuid, nil) do
      SapAgent.stub(:git_status_clean?, true) do
        SapAgent.stub(:write_artifact, Rails.root.join("tmp", "artifact.json")) do
          SapAgent.stub(:git_add, true) do
            SapAgent.stub(:git_commit, "abc123") do
              SapAgent.stub(:tests_green?, true) do
                SapAgent.stub(:git_push, true) do
                  SapAgent.stub(:log_queue_event, true) do
                    result = SapAgent.queue_handshake(
                      artifact: @artifact,
                      task_summary: @task_summary,
                      task_id: @task_id,
                      idempotency_uuid: "uuid-123"
                    )

                    assert_equal "committed", result[:status]
                    assert_equal "abc123", result[:commit_hash]
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "skips duplicate uuid" do
    SapAgent.stub(:git_log_for_uuid, "abc123") do
      SapAgent.stub(:log_queue_event, true) do
        result = SapAgent.queue_handshake(
          artifact: @artifact,
          task_summary: @task_summary,
          task_id: @task_id,
          idempotency_uuid: "uuid-dup"
        )

        assert_equal "skipped", result[:status]
        assert_equal "duplicate", result[:reason]
        assert_equal "abc123", result[:commit_hash]
      end
    end
  end

  test "stashes dirty workspace then commits" do
    status_sequence = [ false, true ]

    SapAgent.stub(:git_log_for_uuid, nil) do
      SapAgent.stub(:git_status_clean?, -> { status_sequence.empty? ? true : status_sequence.shift }) do
        SapAgent.stub(:stash_working_changes, true) do
          SapAgent.stub(:write_artifact, Rails.root.join("tmp", "artifact.json")) do
            SapAgent.stub(:git_add, true) do
              SapAgent.stub(:git_commit, "def456") do
                SapAgent.stub(:tests_green?, true) do
                  SapAgent.stub(:git_push, true) do
                    SapAgent.stub(:pop_stash_with_retry, true) do
                      SapAgent.stub(:log_queue_event, true) do
                        result = SapAgent.queue_handshake(
                          artifact: @artifact,
                          task_summary: @task_summary,
                          task_id: @task_id,
                          idempotency_uuid: "uuid-stash"
                        )

                        assert_equal "committed", result[:status]
                        assert_equal "def456", result[:commit_hash]
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "skips push when DRY_RUN is set" do
    begin
      ENV["DRY_RUN"] = "1"

      SapAgent.stub(:git_log_for_uuid, nil) do
        SapAgent.stub(:git_status_clean?, true) do
          SapAgent.stub(:write_artifact, Rails.root.join("tmp", "artifact.json")) do
            SapAgent.stub(:git_add, true) do
              SapAgent.stub(:git_commit, "789abc") do
                SapAgent.stub(:tests_green?, true) do
                  SapAgent.stub(:git_push, ->(_branch) { raise "should not push" }) do
                    SapAgent.stub(:log_queue_event, true) do
                      result = SapAgent.queue_handshake(
                        artifact: @artifact,
                        task_summary: @task_summary,
                        task_id: @task_id,
                        idempotency_uuid: "uuid-dry"
                      )

                      assert_equal "committed", result[:status]
                      assert_equal "789abc", result[:commit_hash]
                    end
                  end
                end
              end
            end
          end
        end
      end
    ensure
      ENV.delete("DRY_RUN")
    end
  end

  test "returns error when tests fail" do
    SapAgent.stub(:git_log_for_uuid, nil) do
      SapAgent.stub(:git_status_clean?, true) do
        SapAgent.stub(:write_artifact, Rails.root.join("tmp", "artifact.json")) do
          SapAgent.stub(:git_add, true) do
            SapAgent.stub(:git_commit, "fail123") do
              SapAgent.stub(:tests_green?, false) do
                SapAgent.stub(:log_queue_event, true) do
                  pushed = false
                  SapAgent.stub(:git_push, ->(_branch) { pushed = true }) do
                    result = SapAgent.queue_handshake(
                      artifact: @artifact,
                      task_summary: @task_summary,
                      task_id: @task_id,
                      idempotency_uuid: "uuid-tests-fail"
                    )

                    assert_equal "error", result[:status]
                    assert_equal "tests_failed", result[:reason]
                    refute pushed
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "returns error when push fails and pops stash" do
    status_sequence = [ false, true ]
    SapAgent.stub(:git_log_for_uuid, nil) do
      SapAgent.stub(:git_status_clean?, -> { status_sequence.empty? ? true : status_sequence.shift }) do
        SapAgent.stub(:stash_working_changes, true) do
          SapAgent.stub(:write_artifact, Rails.root.join("tmp", "artifact.json")) do
            SapAgent.stub(:git_add, true) do
              SapAgent.stub(:git_commit, "pushfail") do
                SapAgent.stub(:tests_green?, true) do
                  SapAgent.stub(:git_push, false) do
                    popped = false
                    SapAgent.stub(:pop_stash_with_retry, -> { popped = true }) do
                      SapAgent.stub(:log_queue_event, true) do
                        result = SapAgent.queue_handshake(
                          artifact: @artifact,
                          task_summary: @task_summary,
                          task_id: @task_id,
                          idempotency_uuid: "uuid-push-fail"
                        )

                        assert_equal "error", result[:status]
                        assert_equal "push_failed", result[:reason]
                        assert popped
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  test "returns error when stash apply conflicts" do
    status_sequence = [ false, true ]
    SapAgent.stub(:git_log_for_uuid, nil) do
      SapAgent.stub(:git_status_clean?, -> { status_sequence.empty? ? true : status_sequence.shift }) do
        SapAgent.stub(:stash_working_changes, true) do
          SapAgent.stub(:write_artifact, Rails.root.join("tmp", "artifact.json")) do
            SapAgent.stub(:git_add, true) do
              SapAgent.stub(:git_commit, "conflict") do
                SapAgent.stub(:tests_green?, true) do
                  SapAgent.stub(:git_push, true) do
                    SapAgent.stub(:pop_stash_with_retry, false) do
                      SapAgent.stub(:log_queue_event, true) do
                        result = SapAgent.queue_handshake(
                          artifact: @artifact,
                          task_summary: @task_summary,
                          task_id: @task_id,
                          idempotency_uuid: "uuid-stash-conflict"
                        )

                        assert_equal "error", result[:status]
                        assert_equal "stash_apply_conflict", result[:reason]
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

# end of queue_handshake tests
# EOF
# newline padding
# final newline
