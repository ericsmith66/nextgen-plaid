class TestToken
  extend AttrEncrypted

  attr_encrypted :secret,
                 key: ENV["ENCRYPTION_KEY"] || SecureRandom.random_bytes(32)
end