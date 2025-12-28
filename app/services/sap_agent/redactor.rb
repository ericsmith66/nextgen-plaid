require "digest"
require "yaml"

module SapAgent
  module Redactor
    DEFAULT_PATTERN = /\b(API_KEY|SECRET|TOKEN|PASSWORD|ENV[\w_]+)\b/i.freeze
    REDACTION_CONFIG_PATH = Rails.root.join("config/redaction.yml")

    def redact(text)
      return text if text.nil?

      allowlist, denylist = load_lists
      deny_regex = denylist.any? ? Regexp.union(denylist.map { |t| /\b#{Regexp.escape(t)}\b/ }) : nil
      pattern = deny_regex ? Regexp.union(deny_regex, DEFAULT_PATTERN) : DEFAULT_PATTERN

      text.split(/(\s+)/).map do |token|
        next token if allowlist.any? { |allow| token.include?(allow) }

        token.gsub(pattern) { |match| Digest::SHA256.hexdigest(match) }
      end.join
    end

    def load_lists
      return [ [], [] ] unless File.exist?(REDACTION_CONFIG_PATH)

      config = YAML.safe_load(File.read(REDACTION_CONFIG_PATH)) || {}
      [ config.fetch("allowlist", []), config.fetch("denylist", []) ]
    rescue StandardError
      [ [], [] ]
    end

    module_function :redact, :load_lists
  end
end
