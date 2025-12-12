# app/models/enriched_transaction.rb
class EnrichedTransaction < ApplicationRecord
  belongs_to :source_transaction, class_name: "Transaction", foreign_key: "transaction_id"

  validates :transaction_id, presence: true, uniqueness: true
  
  # PRD 7.6: Check if confidence is low
  def low_confidence?
    confidence_level.nil? || confidence_level == "LOW" || confidence_level == "UNKNOWN"
  end
  
  # PRD 7.6: Check if enrichment should be used
  def use_enriched_data?
    !low_confidence? && merchant_name.present?
  end
end
