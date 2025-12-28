namespace :sap do
  namespace :rag do
    desc "Generate a project state snapshot for RAG context"
    task :snapshot => :environment do
      FinancialSnapshotJob.perform_now
    end

    desc "Cleanup old snapshots"
    task :cleanup => :environment do
      FinancialSnapshotJob.new.send(:cleanup_old_snapshots)
    end

    desc "Inspect the RAG context for a specific query type and user"
    task :inspect, [:query_type, :user_id] => :environment do |t, args|
      query_type = args[:query_type] || 'generate'
      user_id = args[:user_id]

      puts "--- SAP RAG INSPECTOR ---"
      puts "Query Type: #{query_type}"
      puts "User ID:    #{user_id || 'None'}"
      puts "-------------------------"

      prefix = SapAgent::RagProvider.build_prefix(query_type, user_id)
      
      puts "\n--- GENERATED RAG PREFIX ---"
      puts prefix
      puts "----------------------------"
      
      # Additional analysis
      puts "\n--- ANALYSIS ---"
      if prefix.include?("[REDACTED]")
        puts "✅ PII Anonymization: Active (Redacted tokens found)"
      else
        puts "⚠️ PII Anonymization: Not verified (No redacted tokens found - check if snapshot exists)"
      end

      if prefix.include?("[TRUNCATED]")
        puts "⚠️ Truncation: Active (Context exceeded limit)"
      else
        puts "✅ Truncation: Not triggered (Context within limits)"
      end

      if prefix.include?("DOC_NOT_FOUND") || prefix.include?("Fallback to minimal prefix")
        puts "❌ Errors: Found warnings/fallbacks in prefix"
      elsif prefix.include?("--- STATIC DOCUMENTS ---\n\n--- USER DATA SNAPSHOT ---")
        puts "⚠️ Content: Both static documents and user snapshot are empty/missing!"
      else
        puts "✅ Content: No immediate errors found in prefix generation"
      end
    end
  end
end
