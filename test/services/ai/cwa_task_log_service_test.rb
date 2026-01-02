require "test_helper"

class CwaTaskLogServiceTest < ActiveSupport::TestCase
  test "persists and reloads log" do
    correlation_id = "cid-log-1"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.rm_rf(run_dir)

    writer = AiWorkflowService::ArtifactWriter.new(correlation_id)
    svc = Ai::CwaTaskLogService.new(correlation_id: correlation_id, artifact_writer: writer)

    ctx = Struct.new(:context).new({ micro_tasks: [ { "id" => 1, "title" => "Do thing" } ] })
    svc.on_run_start("SAP", "User request: hello", ctx)
    svc.on_agent_handoff("Coordinator", "CWA", "implementation")
    svc.on_tool_start("SafeShellTool", { "cmd" => "bundle exec ruby -v" })
    svc.on_tool_complete("SafeShellTool", { ok: true }.to_json)

    assert File.exist?(run_dir.join("cwa_log.json"))
    assert File.exist?(run_dir.join("cwa_log.md"))

    reloaded = Ai::CwaTaskLogService.new(correlation_id: correlation_id, artifact_writer: writer)
    assert_equal correlation_id, reloaded.snapshot["correlation_id"]
    assert_includes reloaded.markdown, correlation_id
  ensure
    FileUtils.rm_rf(run_dir)
  end

  test "truncates when exceeding max bytes" do
    correlation_id = "cid-log-2"
    run_dir = Rails.root.join("agent_logs", "ai_workflow", correlation_id)
    FileUtils.rm_rf(run_dir)

    writer = AiWorkflowService::ArtifactWriter.new(correlation_id)
    svc = Ai::CwaTaskLogService.new(correlation_id: correlation_id, artifact_writer: writer)
    svc.on_agent_handoff("Coordinator", "CWA", "implementation")

    # Create many execute entries with large args to exceed 100k.
    300.times do |i|
      svc.on_tool_start("GitTool", { "action" => "status", "padding" => ("x" * 500) })
      svc.on_tool_complete("GitTool", { i: i, ok: true }.to_json)
    end

    cwa_log = JSON.parse(File.read(run_dir.join("cwa_log.json")))
    assert_equal true, cwa_log["truncated"], "expected log to be marked truncated"
    assert File.size(run_dir.join("cwa_log.md")) <= Ai::CwaTaskLogService::MAX_BYTES + 5_000,
           "expected markdown log to be roughly capped"
  ensure
    FileUtils.rm_rf(run_dir)
  end
end
