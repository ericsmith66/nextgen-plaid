require "test_helper"

class AgentSandboxRunnerTest < ActiveSupport::TestCase
  test "run parses inner JSON output from sandbox runner" do
    inner = {
      status: 7,
      stdout: "inner-out",
      stderr: "inner-err"
    }

    fake_stdout = JSON.generate(inner)
    fake_stderr = "wrapper-stderr"
    fake_status = Struct.new(:exitstatus).new(0)

    Open3.stub(:capture3, [ fake_stdout, fake_stderr, fake_status ]) do
      result = AgentSandboxRunner.run(
        cmd: "echo hi",
        argv: %w[echo hi],
        cwd: Rails.root.to_s,
        correlation_id: "cid-1",
        tool_name: "Test",
        timeout_seconds: 1
      )

      assert_equal 7, result[:status]
      assert_equal "inner-out", result[:stdout]
      assert_equal "inner-err", result[:stderr]
    end
  end

  test "run falls back to wrapper output when sandbox stdout is not JSON" do
    fake_stdout = "not-json"
    fake_stderr = "wrapper-stderr"
    fake_status = Struct.new(:exitstatus).new(3)

    Open3.stub(:capture3, [ fake_stdout, fake_stderr, fake_status ]) do
      result = AgentSandboxRunner.run(
        cmd: "echo hi",
        argv: %w[echo hi],
        cwd: Rails.root.to_s,
        correlation_id: "cid-1",
        tool_name: "Test",
        timeout_seconds: 1
      )

      assert_equal 3, result[:status]
      assert_equal "not-json", result[:stdout]
      assert_equal "wrapper-stderr", result[:stderr]
    end
  end
end
