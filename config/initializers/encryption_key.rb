hex = ENV["ENCRYPTION_KEY"]

if hex.nil? || hex.strip.empty?
  raise "ENCRYPTION_KEY is missing. Set a 64-hex-character key in the environment."
end

unless hex.match?(/\A[0-9a-fA-F]{64}\z/)
  raise "ENCRYPTION_KEY must be a 64-character hex string (32 bytes)."
end

# Shared binary key used by attr_encrypted
ACCESS_TOKEN_ENCRYPTION_KEY = [hex].pack('H*')
