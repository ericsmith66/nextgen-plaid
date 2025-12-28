namespace :sap do
  desc "Scan knowledge_base for epics and PRDs and update inventory.json"
  task :inventory => :environment do
    INVENTORY_PATH = Rails.root.join('knowledge_base/inventory.json')
    EPICS_DIR = Rails.root.join('knowledge_base/epics')
    PRDS_DIR = Rails.root.join('knowledge_base/prds')
    
    inventory = []
    
    # Scan Epics
    Dir.glob(EPICS_DIR.join('**/*.md')).each do |file|
      inventory << parse_md_file(file)
    end
    
    # Scan PRDs
    Dir.glob(PRDS_DIR.join('**/*.md')).each do |file|
      inventory << parse_md_file(file)
    end
    
    inventory.compact!
    
    File.write(INVENTORY_PATH, JSON.pretty_generate(inventory))
    Rails.logger.info({ event: "sap.inventory.updated", count: inventory.size }.to_json)
    puts "Inventory updated with #{inventory.size} files."
  end

  def parse_md_file(path)
    content = File.read(path)
    
    # Match frontmatter
    frontmatter_match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
    metadata = {}
    
    if frontmatter_match
      yaml_content = frontmatter_match[1]
      metadata[:title] = yaml_content.match(/title:\s*(.*)/)&.[](1)&.strip
      metadata[:priority] = yaml_content.match(/priority:\s*(.*)/)&.[](1)&.strip
      metadata[:status] = yaml_content.match(/status:\s*(.*)/)&.[](1)&.strip
      metadata[:version] = yaml_content.match(/version:\s*(.*)/)&.[](1)&.strip
    end
    
    # Fallbacks if frontmatter missing or incomplete
    metadata[:title] ||= content.match(/^# (.*)/)&.[](1)&.strip
    metadata[:title] ||= File.basename(path, '.md')
    
    metadata[:id] = File.basename(path).match(/^(\d+)/)&.[](1) || "unknown"
    metadata[:path] = path.to_s.gsub(Rails.root.to_s + '/', '')
    metadata[:last_modified] = File.mtime(path)
    
    metadata
  end
end