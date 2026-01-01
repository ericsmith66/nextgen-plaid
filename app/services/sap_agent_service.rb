require "json"
require "net/http"

class SapAgentService
  def self.default_model
    ENV["SAP_CHAT_MODEL"].presence || SapAgent::Config::MODEL_DEFAULT
  end

  # Streams tokens/chunks from SmartProxy.
  #
  # SmartProxy is expected to proxy Ollama/OpenAI-like streaming responses.
  # We try to be resilient by accepting:
  # - JSON lines (Ollama-style) with `{"response":"..."}` or `{"message":{"content":"..."}}`
  # - SSE-style `data: {...}` lines
  # - OpenAI-style deltas: `choices[0].delta.content`
  def self.stream(prompt, model: default_model, request_id: nil)
    raise ArgumentError, "block required" unless block_given?

    smart_proxy_url = ENV["SMART_PROXY_URL"]
    smart_proxy_port = ENV["SMART_PROXY_PORT"]
    default_port = Rails.env.test? ? 3002 : 3001

    uri = if smart_proxy_url.present?
      URI(smart_proxy_url)
    else
      URI("http://localhost:#{smart_proxy_port.presence || default_port}/proxy/generate")
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 300

    auth_token = ENV["PROXY_AUTH_TOKEN"]
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request["Authorization"] = "Bearer #{auth_token}" if auth_token.present?
    request["X-Request-ID"] = request_id if request_id.present?
    request.body = {
      model: model,
      messages: [
        { role: "user", content: prompt }
      ],
      stream: true
    }.to_json

    buffer = +""
    yielded_any = false

    http.request(request) do |response|
      unless response.is_a?(Net::HTTPSuccess)
        raise "SmartProxy returned #{response.code}: #{response.body.to_s.truncate(200)}"
      end

      response.read_body do |chunk|
        buffer << chunk

        while (newline_index = buffer.index("\n"))
          raw_line = buffer.slice!(0..newline_index)
          line = raw_line.strip
          next if line.blank?

          # SSE handling
          if line.start_with?("data:")
            line = line.sub(/\Adata:\s*/, "")
            next if line == "[DONE]"
          end

          parsed = begin
            JSON.parse(line)
          rescue JSON::ParserError
            nil
          end
          next if parsed.blank?

          text = parsed.dig("choices", 0, "delta", "content") ||
            parsed.dig("choices", 0, "message", "content") ||
            parsed.dig("message", "content") ||
            parsed["response"] ||
            parsed["content"]

          if text.present?
            yielded_any = true
            yield(text)
          end
        end
      end

      # SmartProxy currently returns `response.body.to_json`, which means we may receive:
      # - a JSON object encoded as a JSON string
      # - SSE (`data: {...}` lines) encoded as a JSON string with escaped newlines
      # If we didn't yield anything during streaming parsing, fall back to decoding once.
      next if yielded_any

      decoded = begin
        JSON.parse(buffer)
      rescue JSON::ParserError
        buffer
      end

      if decoded.is_a?(String)
        # Might be SSE content in a string.
        decoded.split("\n").each do |raw|
          line = raw.strip
          next if line.blank?

          if line.start_with?("data:")
            line = line.sub(/\Adata:\s*/, "")
            next if line == "[DONE]"
          end

          parsed = begin
            JSON.parse(line)
          rescue JSON::ParserError
            nil
          end
          next if parsed.blank?

          text = parsed.dig("choices", 0, "delta", "content") ||
            parsed.dig("choices", 0, "message", "content") ||
            parsed.dig("message", "content") ||
            parsed["response"] ||
            parsed["content"]

          yield(text) if text.present?
        end
      elsif decoded.is_a?(Hash)
        text = decoded.dig("choices", 0, "message", "content") ||
          decoded.dig("message", "content") ||
          decoded["response"] ||
          decoded["content"]
        yield(text) if text.present?
      end
    end
  end
end
