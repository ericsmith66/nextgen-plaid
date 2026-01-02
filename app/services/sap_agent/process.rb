# frozen_string_literal: true

# This class exists to provide an explicit, autoloadable object for the new PRD-50F
# structured SAP entrypoint. The canonical public API remains `SapAgent.process`.
module SapAgent
  class Process
    def self.call(query, **kwargs)
      SapAgent.process(query, **kwargs)
    end
  end
end
