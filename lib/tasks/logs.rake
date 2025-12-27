namespace :logs do
  desc "Rotate agent logs (sap.log, smart_proxy.log)"
  task rotate: :environment do
    logs = [
      Rails.root.join('agent_logs/sap.log'),
      Rails.root.join('log/smart_proxy.log')
    ]

    date_str = Time.now.strftime('%Y-%m-%d')

    logs.each do |log_path|
      next unless File.exist?(log_path)

      new_path = "#{log_path}.#{date_str}"
      
      # Use system copy and clear to be safe
      FileUtils.cp(log_path, new_path)
      File.open(log_path, 'w') { |f| f.truncate(0) }
      
      puts "Rotated #{log_path} to #{new_path}"
    end
  end
end
