module SapAgent
  module Config
    ITERATION_CAP = 7
    TOKEN_BUDGET = 80000
    SCORE_STOP_THRESHOLD = 80
    SCORE_ESCALATE_THRESHOLD = 70
    OFFENSE_LIMIT = 20
    RUBOCOP_TIMEOUT_SECONDS = 30
    BACKOFF_MS = [ 150, 300 ].freeze

    ADAPTIVE_RETRY_LIMIT = 2
    ADAPTIVE_ITERATION_CAP = ITERATION_CAP
    ADAPTIVE_TOKEN_BUDGET = TOKEN_BUDGET
    ADAPTIVE_ESCALATION_ORDER = %w[grok-4.1 claude-sonnet-4.5 ollama].freeze
    ADAPTIVE_MAX_ESCALATIONS = 1

    # Keep this intentionally low to ensure pruning engages early enough for typical prompt windows.
    # Tests expect pruning to occur when token count exceeds ~5000.
    PRUNE_TARGET_TOKENS = 5000
    PRUNE_MIN_KEEP_TOKENS = 2000
    PRUNE_BACKOFF_MS = [ 150, 300 ].freeze

    MODEL_DEFAULT = "ollama".freeze
    MODEL_ESCALATE = "grok-4.1".freeze
    MODEL_FALLBACK = "claude-sonnet-4.5".freeze
  end
end
