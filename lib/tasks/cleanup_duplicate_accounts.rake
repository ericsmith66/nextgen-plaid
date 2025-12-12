# lib/tasks/cleanup_duplicate_accounts.rake
namespace :accounts do
  desc "Cleanup duplicate accounts created during re-linking"
  task cleanup_duplicates: :environment do
    puts "Scanning for duplicate accounts..."
    
    PlaidItem.find_each do |item|
      # Group accounts by name, mask, and type
      grouped = item.accounts.group_by { |a| [a.name, a.mask, a.type] }
      
      grouped.each do |(name, mask, type), accounts|
        next if accounts.size <= 1
        
        puts "\nFound #{accounts.size} duplicates for: #{name} (#{mask}) [#{type}]"
        
        # Sort by created_at - keep the oldest, merge data into it
        accounts_sorted = accounts.sort_by(&:created_at)
        primary_account = accounts_sorted.first
        duplicates = accounts_sorted[1..]
        
        puts "  Primary account (keeping): ID #{primary_account.id}, created #{primary_account.created_at}"
        
        duplicates.each do |dup|
          puts "  Merging duplicate: ID #{dup.id}, created #{dup.created_at}"
          
          # Move positions to primary account
          dup.positions.each do |pos|
            existing_pos = primary_account.positions.find_by(security_id: pos.security_id)
            if existing_pos
              # Update existing position with latest data
              existing_pos.update!(
                symbol: pos.symbol,
                name: pos.name,
                quantity: pos.quantity,
                cost_basis: pos.cost_basis,
                market_value: pos.market_value
              )
              pos.destroy
            else
              pos.update!(account_id: primary_account.id)
            end
          end
          
          # Move transactions to primary account
          dup.transactions.each do |txn|
            existing_txn = primary_account.transactions.find_by(transaction_id: txn.transaction_id)
            if existing_txn
              # Update existing transaction
              existing_txn.update!(
                name: txn.name,
                amount: txn.amount,
                date: txn.date,
                category: txn.category,
                merchant_name: txn.merchant_name,
                pending: txn.pending,
                payment_channel: txn.payment_channel,
                iso_currency_code: txn.iso_currency_code
              )
              txn.destroy
            else
              txn.update!(account_id: primary_account.id)
            end
          end
          
          # Move liabilities to primary account
          dup.liabilities.each do |liability|
            existing_liability = primary_account.liabilities.find_by(liability_id: liability.liability_id)
            if existing_liability
              existing_liability.update!(
                liability_type: liability.liability_type,
                current_balance: liability.current_balance,
                min_payment_due: liability.min_payment_due,
                apr_percentage: liability.apr_percentage,
                payment_due_date: liability.payment_due_date
              )
              liability.destroy
            else
              liability.update!(account_id: primary_account.id)
            end
          end
          
          # Update primary account with most recent data from duplicate
          primary_account.update!(
            current_balance: dup.current_balance,
            iso_currency_code: dup.iso_currency_code,
            subtype: dup.subtype
          )
          
          # Delete the duplicate account
          dup.destroy
          puts "    ✓ Merged and deleted duplicate ID #{dup.id}"
        end
      end
    end
    
    puts "\n✓ Cleanup complete!"
  end
end
