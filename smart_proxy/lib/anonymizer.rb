class Anonymizer
  PII_PATTERNS = {
    email: /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
    phone: /\b(?:\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/,
    ssn: /\b\d{3}-\d{2}-\d{4}\b/,
    credit_card: /\b(?:\d[ -]*?){13,16}\b/
  }.freeze

  def self.anonymize(data)
    case data
    when Hash
      data.each_with_object({}) { |(k, v), h| h[k] = anonymize(v) }
    when Array
      data.map { |v| anonymize(v) }
    when String
      anonymize_string(data)
    else
      data
    end
  end

  def self.anonymize_string(text)
    result = text.dup
    PII_PATTERNS.each do |label, pattern|
      result.gsub!(pattern, "[#{label.to_s.upcase}]")
    end
    result
  end
end
