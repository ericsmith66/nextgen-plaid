module SapAgent
  module EpicStrategy
    def self.validate_output!(response)
      raise "Output missing 'Overview'" unless response.include?('#### Overview')
      raise "Output missing 'Atomic PRDs'" unless response.include?('#### Atomic PRDs')
      raise "Output missing 'Success Criteria'" unless response.include?('#### Success Criteria')
      raise "Output missing 'Capabilities Built'" unless response.include?('#### Capabilities Built')
    end

    def self.parse_output(response)
      {
        content: response,
        slug: response.match(/## (.*) Epic Overview/)&.[](1)&.parameterize || "generated-epic"
      }
    end

    def self.store!(data)
      slug = data[:slug]
      dir = Rails.root.join("knowledge_base/epics/#{slug}")
      FileUtils.mkdir_p(dir)
      
      filename = "0000-Overview.md"
      File.write(dir.join(filename), data[:content])
    end
  end
end
