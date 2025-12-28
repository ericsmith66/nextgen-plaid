module SapAgent
  module TimeoutWrapper
    def with_timeout(seconds, &block)
      Timeout.timeout(seconds, &block)
    end

    module_function :with_timeout
  end
end
