module SapAgent
  module PrdStrategy
    def self.validate_output!(response)
      raise "Output missing 'Overview'" unless response.include?('#### Overview')
      raise "Output missing 'Acceptance Criteria'" unless response.include?('#### Acceptance Criteria')
      
      ac_count = response.scan(/^\s*-\s+/).count
      # Note: This regex might be too broad if other sections use bullets. 
      # Let's try to be more specific to AC section if possible.
      ac_section = response.match(/#### Acceptance Criteria(.*?)(####|\z)/m)&.[](1)
      if ac_section
        ac_bullets = ac_section.scan(/^\s*-\s+/).count
        raise "Acceptance Criteria must be between 5 and 8 bullets (found #{ac_bullets})" unless ac_bullets.between?(5, 8)
      end

      raise "Output missing 'Architectural Context'" unless response.include?('#### Architectural Context')
      raise "Output missing 'Test Cases'" unless response.include?('#### Test Cases')
    end

    def self.parse_output(response)
      # For PRD, the output IS the artifact
      {
        content: response,
        slug: response.match(/## \d+-(.*)-PRD.md/)&.[](1) || "generated-prd",
        id: response.match(/## (\d+)-/)&.[](1) || "0000"
      }
    end

    def self.store!(data)
      slug = data[:slug]
      id = data[:id]
      dir = Rails.root.join("knowledge_base/epics/#{slug}")
      FileUtils.mkdir_p(dir)
      
      filename = "#{id}-#{slug}-PRD.md"
      File.write(dir.join(filename), data[:content])
    end
  end
end
