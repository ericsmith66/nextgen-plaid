# frozen_string_literal: true

require "test_helper"
require "net/http"
require "json"

# Live smoke tests for SmartProxy.
#
# These tests intentionally hit a *running* SmartProxy instance over HTTP.
# They are skipped by default.
#
# Run:
#   SMART_PROXY_LIVE_TEST=true bin/rails test test/smoke/smart_proxy_live_test.rb
#
class SmartProxyLiveTest < ActiveSupport::TestCase
  def setup
    super
    skip "Set SMART_PROXY_LIVE_TEST=true to enable" unless ENV["SMART_PROXY_LIVE_TEST"] == "true"

    # These tests are intentionally "live" and should not be intercepted by VCR.
    if defined?(VCR)
      @vcr_was_turned_on = VCR.turned_on?
      VCR.turn_off!
    end

    # WebMock is used across the test suite; allow real HTTP for these live tests.
    if defined?(WebMock)
      @webmock_was_allowing_net_connect = WebMock.net_connect_allowed?
      WebMock.allow_net_connect!
    end

    @port = ENV.fetch("SMART_PROXY_PORT", "3002")
    @base = URI("http://localhost:#{@port}")
    @token = ENV["PROXY_AUTH_TOKEN"].to_s
  end

  def teardown
    if defined?(WebMock) && !@webmock_was_allowing_net_connect
      WebMock.disable_net_connect!(allow_localhost: true)
    end

    if defined?(VCR) && @vcr_was_turned_on
      VCR.turn_on!
    end
    super
  end

  def test_health
    res = http_get("/health")
    assert_equal 200, res.code.to_i
    body = JSON.parse(res.body)
    assert_equal "ok", body["status"]
  end

  def test_models_endpoint_is_openai_shaped
    res = http_get("/v1/models")
    assert_equal 200, res.code.to_i
    body = JSON.parse(res.body)
    assert_equal "list", body["object"]
    assert body["data"].is_a?(Array)
  end

  def test_chat_completions_ollama_style_with_tools_returns_choices_and_usage
    res = http_post_json("/v1/chat/completions", {
      model: ENV.fetch("OLLAMA_MODEL", "llama3.1:70b"),
      messages: [
        { role: "developer", content: "You are a helpful assistant." },
        { role: "user", content: "Say hello in one short sentence." }
      ],
      stream: false,
      temperature: 0.2,
      tools: [
        {
          type: "function",
          function: {
            name: "noop",
            description: "No-op tool",
            parameters: { type: "object", properties: {}, required: [] }
          }
        }
      ]
    })

    assert_equal 200, res.code.to_i
    body = JSON.parse(res.body)
    assert body["choices"].is_a?(Array), "expected choices array"
    assert body.dig("choices", 0, "message", "content").present?, "expected message content"
    assert body["usage"].is_a?(Hash), "expected usage hash"
    assert body.dig("usage", "prompt_tokens").is_a?(Integer)
    assert body.dig("usage", "completion_tokens").is_a?(Integer)
    assert body.dig("usage", "total_tokens").is_a?(Integer)
  end

  def test_chat_completions_grok_style_if_configured
    skip "GROK_API_KEY not set; skipping Grok live test" if ENV["GROK_API_KEY"].blank?

    grok_model = ENV.fetch("GROK_MODEL", "grok-4")

    res = http_post_json("/v1/chat/completions", {
      model: grok_model,
      messages: [
        { role: "system", content: "You are a helpful assistant." },
        { role: "user", content: "Reply with the word OK." }
      ],
      stream: false,
      temperature: 0.0,
      tools: []
    })

    assert_equal 200, res.code.to_i, "Grok returned HTTP #{res.code}: #{res.body.to_s.tr("\n", " ")[0, 500]}"

    body = JSON.parse(res.body)
    assert body["choices"].is_a?(Array), "expected choices array"
    assert body.dig("choices", 0, "message", "content").present?
    assert body["usage"].is_a?(Hash), "expected usage hash"
  end

  def test_grok_live_search_price_question_if_configured
    skip "GROK_API_KEY not set; skipping Grok live-search test" if ENV["GROK_API_KEY"].blank?

    grok_model = ENV.fetch("GROK_MODEL", "grok-4")

    res = http_post_json("/v1/chat/completions", {
      model: grok_model,
      messages: [
        { role: "system", content: "You are a helpful assistant. Use live web search when needed." },
        { role: "user", content: "What is the price of Tesla (TSLA) on today's date? Provide the price and the source you used." }
      ],
      stream: false,
      temperature: 0.0,
      tools: [
        {
          type: "function",
          function: {
            name: "web_search",
            description: "Search the web for up-to-date information.",
            parameters: {
              type: "object",
              properties: {
                query: { type: "string" },
                num_results: { type: "integer" }
              },
              required: ["query"]
            }
          }
        }
      ]
    })

    assert_equal 200, res.code.to_i, "Grok live-search returned HTTP #{res.code}: #{res.body.to_s.tr("\n", " ")[0, 500]}"

    body = JSON.parse(res.body)
    msg = body.dig("choices", 0, "message") || {}

    content = msg["content"].to_s
    tool_calls = msg["tool_calls"]

    # Some Grok responses may return tool calls with empty content.
    assert(
      content.present? || tool_calls.present?,
      "expected message content or tool_calls, got: #{msg.inspect}"
    )

    if tool_calls.present?
      # If tools were requested, ensure we at least see the `web_search` tool being called.
      tool_names = tool_calls.map { |tc| tc.dig("function", "name") }.compact
      assert_includes tool_names, "web_search"
    end

    # If content is present, do lightweight validation.
    if content.present?
      assert_match(/TSLA|Tesla/i, content)
      # We don't validate the exact price (varies intraday), but require some source/citation text.
      assert_match(/source|http|www\./i, content)
    end
  end

  private

  def http_get(path)
    uri = @base + path
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{@token}" if @token.present?
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end

  def http_post_json(path, payload)
    uri = @base + path
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Authorization"] = "Bearer #{@token}" if @token.present?
    req.body = JSON.dump(payload)
    Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
  end
end
