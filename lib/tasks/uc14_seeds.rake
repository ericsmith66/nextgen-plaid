# UC-14 Seed tasks for lookups
namespace :uc14 do
  desc "Seed Personal Finance Categories from Plaid CSV taxonomy"
  task :seed_pfc, [:url] => :environment do |_, args|
    require 'csv'
    url = args[:url] || 'https://plaid.com/documents/transactions-personal-finance-category-taxonomy.csv'
    tmp = Rails.root.join('tmp', 'pfc_taxonomy.csv')
    require 'open-uri'
    URI.open(url) { |io| File.write(tmp, io.read) }

    inserted = 0
    CSV.foreach(tmp, headers: true) do |row|
      primary = row['Primary Category'] || row['primary']
      detailed = row['Detailed Category'] || row['detailed']
      long_desc = row['Description'] || row['long_description']
      next if primary.blank? || detailed.blank?

      rec = PersonalFinanceCategory.find_or_initialize_by(primary: primary, detailed: detailed)
      rec.long_description = long_desc if long_desc.present?
      inserted += 1 if rec.changed? && rec.save!
    end

    puts({ event: 'uc14.seed_pfc', inserted: inserted }.to_json)
  end

  desc "Seed Transaction Codes (EU list)"
  task :seed_transaction_codes => :environment do
    codes = [
      { code: 'adjustment', name: 'Adjustment' },
      { code: 'atm', name: 'ATM' },
      { code: 'bank charge', name: 'Bank charge' },
      { code: 'bill payment', name: 'Bill payment' },
      { code: 'cash', name: 'Cash' },
      { code: 'cashback', name: 'Cashback' },
      { code: 'cheque', name: 'Cheque' },
      { code: 'direct debit', name: 'Direct debit' },
      { code: 'interest', name: 'Interest' },
      { code: 'purchase', name: 'Purchase' },
      { code: 'standing order', name: 'Standing order' },
      { code: 'transfer', name: 'Transfer' }
    ]

    inserted = 0
    codes.each do |c|
      rec = TransactionCode.find_or_initialize_by(code: c[:code])
      rec.name ||= c[:name]
      inserted += 1 if rec.changed? && rec.save!
    end
    puts({ event: 'uc14.seed_transaction_codes', inserted: inserted }.to_json)
  end
end
