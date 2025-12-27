module SapAgent
  class GenerateCommand < ArtifactCommand
    def validate!
      # Ensure strategy is set if not provided in payload
      payload[:strategy] ||= infer_strategy(payload[:query])
      super
    end

    private

    def infer_strategy(query)
      case query.downcase
      when /backlog/
        :backlog
      when /epic/
        :epic
      else
        :prd
      end
    end
  end
end
