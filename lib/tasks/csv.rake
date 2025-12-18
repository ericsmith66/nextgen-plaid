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

  desc "Import holdings from CSV file - Usage: rake csv:import_holdings[file_path,user_id]"
  task :import_holdings, [ :file_path, :user_id ] => :environment do |_t, args|
    unless args[:file_path]
      puts "Error: file_path is required"
      puts "Usage: rake csv:import_holdings['/path/to/holdings.csv',user_id]"
      exit 1
    end

    # Get user from argument or ENV variable
    user_id = args[:user_id] || ENV["USER_ID"]
    unless user_id
      puts "Error: user_id is required"
      puts "Usage: rake csv:import_holdings['/path/to/holdings.csv',user_id]"
      puts "Or set USER_ID environment variable"
      exit 1
    end

    user = User.find_by(id: user_id)
    unless user
      puts "Error: User with id #{user_id} not found"
      exit 1
    end

    puts "Starting CSV holdings import for user #{user.email} (ID: #{user.id})"
    puts "File: #{args[:file_path]}"

    importer = CsvHoldingsImporter.new(args[:file_path])
    success = importer.call(user: user)

    if success
      puts "\n✓ Import completed successfully!"
      puts "  - Imported: #{importer.imported_count} holdings"
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

namespace :csv do
  desc "Import transactions from CSV file - Usage: rake csv:import_transactions[file_path,user_id]"
  task :import_transactions, [ :file_path, :user_id ] => :environment do |_t, args|
    unless args[:file_path]
      puts "Error: file_path is required"
      puts "Usage: rake csv:import_transactions['/path/to/transactions.csv',user_id]"
      exit 1
    end

    # Get user from argument or ENV variable
    user_id = args[:user_id] || ENV["USER_ID"]
    unless user_id
      puts "Error: user_id is required"
      puts "Usage: rake csv:import_transactions['/path/to/transactions.csv',user_id]"
      puts "Or set USER_ID environment variable"
      exit 1
    end

    user = User.find_by(id: user_id)
    unless user
      puts "Error: User with id #{user_id} not found"
      exit 1
    end

    puts "Starting CSV transactions import for user #{user.email} (ID: #{user.id})"
    puts "File: #{args[:file_path]}"

    result = CsvTransactionsImporter.call(file_path: args[:file_path], user_id: user.id)

    total_created_or_updated = result.inserted.to_i + result.updated.to_i
    if total_created_or_updated > 0
      if defined?(FinancialSnapshotJob)
        FinancialSnapshotJob.perform_later(user.id)
        puts "Queued FinancialSnapshotJob for user #{user.id}"
      else
        puts "Note: FinancialSnapshotJob not defined; skipping snapshot enqueue"
      end
    end

    puts "\nSummary:"
    puts "  - Inserted: #{result.inserted}"
    puts "  - Updated: #{result.updated}"
    puts "  - Duplicated: #{result.duplicated}"
    puts "  - Filtered: #{result.filtered}"
    puts "  - Invalid date: #{result.invalid_date}"
    puts "  - No account: #{result.no_account}"
    puts "  - Skipped zero: #{result.skipped_zero}"
    puts "  - Unmapped category: #{result.unmapped_category}"
    puts "  - Total rows: #{result.total_rows}"
    puts "  - Processed rows: #{result.processed_rows}"
    puts "  - Errors CSV: #{result.errors_path || 'none'}"

    exit 0
  end
end
