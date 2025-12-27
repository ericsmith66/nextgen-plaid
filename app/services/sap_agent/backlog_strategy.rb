require 'json'

module SapAgent
  module BacklogStrategy
    BACKLOG_PATH = Rails.root.join('knowledge_base/backlog.json')

    def self.validate_output!(response)
      # Backlog AI output should be a JSON block or at least contain the mandatory keys
      # Often AI wraps JSON in ```json ... ```
      json_match = response.match(/```json\s*(.*?)\s*```/m) || response.match(/(\{.*?\})/m)
      raise "Output missing JSON block for backlog update" unless json_match
      
      begin
        data = JSON.parse(json_match[1])
        required_keys = %w[priority title description status dependencies effort deadline]
        missing_keys = required_keys - data.keys
        raise "JSON missing keys: #{missing_keys.join(', ')}" unless missing_keys.empty?
      rescue JSON::ParserError
        raise "Invalid JSON in output"
      end
    end

    def self.parse_output(response)
      json_match = response.match(/```json\s*(.*?)\s*```/m) || response.match(/(\{.*?\})/m)
      data = JSON.parse(json_match[1])
      
      # Ruby-enforced ID generation
      data['id'] = next_id
      data
    end

    def self.store!(data)
      File.open(BACKLOG_PATH, File::RDWR | File::CREAT) do |f|
        f.flock(File::LOCK_EX)
        raw_content = f.read
        current_backlog = raw_content.present? ? JSON.parse(raw_content) : []
        
        # Merge or add
        existing_index = current_backlog.find_index { |item| item['id'] == data['id'] }
        if existing_index
          current_backlog[existing_index] = data
        else
          current_backlog << data
        end

        f.rewind
        f.write(JSON.pretty_generate(current_backlog))
        f.flush
        f.truncate(f.pos)
      end
    end

    private

    def self.next_id
      return "0010" unless File.exist?(BACKLOG_PATH)
      
      content = File.read(BACKLOG_PATH)
      return "0010" if content.blank?
      
      backlog = JSON.parse(content)
      return "0010" if backlog.empty?
      
      last_id = backlog.map { |item| item['id'].to_i }.max
      (last_id + 1).to_s.rjust(4, '0')
    end
  end
end
