# lib/tasks/csv.rake
# CSV-3: Rake tasks for CSV imports

namespace :csv do
  desc "Import accounts from CSV file - Usage: rake csv:import_accounts[file_path,user_id]"
  task :import_accounts, [ :file_path, :user_id ] => :environment do |_t, args|
    unless args[:file_path]
      puts "Error: file_path is required"
      puts "Usage: rake csv:import_accounts['/path/to/accounts.csv',user_id]"
      exit 1
    end

    # Get user from argument or ENV variable
    user_id = args[:user_id] || ENV["USER_ID"]
    unless user_id
      puts "Error: user_id is required"
      puts "Usage: rake csv:import_accounts['/path/to/accounts.csv',user_id]"
      puts "Or set USER_ID environment variable"
      exit 1
    end

    user = User.find_by(id: user_id)
    unless user
      puts "Error: User with id #{user_id} not found"
      exit 1
    end

    puts "Starting CSV import for user #{user.email} (ID: #{user.id})"
    puts "File: #{args[:file_path]}"

    importer = CsvAccountsImporter.new(args[:file_path])
    success = importer.call(user: user)

    if success
      puts "\n✓ Import completed successfully!"
      puts "  - Imported: #{importer.imported_count} accounts"
      puts "  - Skipped: #{importer.skipped_count} rows"
    else
      puts "\n✗ Import failed!"
    end

    if importer.errors.any?
      puts "\nErrors/Warnings:"
      importer.errors.each { |error| puts "  - #{error}" }
    end

    exit(success ? 0 : 1)
  end
end
