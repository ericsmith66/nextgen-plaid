# frozen_string_literal: true

require "json"

class TaskBreakdownTool < Agents::Tool
  description "Parse a PRD into 5–10 micro-tasks and store them into context[:micro_tasks] as structured JSON."
  param :prd_text, type: "string", desc: "Full PRD text (Markdown) to decompose into micro-tasks"

  MAX_TASKS = 10
  MIN_TASKS = 5

  def perform(tool_context, prd_text:)
    prd_text = prd_text.to_s
    tasks = build_tasks_from_text(prd_text)

    tool_context.context[:micro_tasks] = tasks
    JSON.pretty_generate(tasks)
  end

  private

  def build_tasks_from_text(text)
    headings = text.lines.filter_map do |line|
      line = line.to_s.strip
      next unless line.start_with?("#")
      title = line.gsub(/^#+\s*/, "").strip
      next if title.blank?
      title
    end

    seeds = headings.first(MAX_TASKS)
    seeds = default_seeds if seeds.length < MIN_TASKS

    seeds.first(MAX_TASKS).each_with_index.map do |title, idx|
      {
        "id" => format("task-%02d", idx + 1),
        "title" => title.to_s,
        "files" => [],
        "commands" => [],
        "risk" => idx.zero? ? "med" : "low",
        "estimate" => idx.zero? ? "30m" : "20m"
      }
    end
  end

  def default_seeds
    [
      "Review PRD requirements and acceptance criteria",
      "Identify impacted services/controllers/components",
      "Implement core changes",
      "Add tests (unit + integration)",
      "Run full test suite and update docs"
    ]
  end
end
