module SapAgent
  module Config
    ITERATION_CAP = 5
    TOKEN_BUDGET = 1000
    SCORE_STOP_THRESHOLD = 80
    SCORE_ESCALATE_THRESHOLD = 70
    OFFENSE_LIMIT = 20
    RUBOCOP_TIMEOUT_SECONDS = 30
    BACKOFF_MS = [ 150, 300 ].freeze

    MODEL_DEFAULT = "ollama".freeze
    MODEL_ESCALATE = "grok-4.1".freeze
    MODEL_FALLBACK = "claude-sonnet-4.5".freeze
  end
end
