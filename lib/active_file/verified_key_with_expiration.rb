class ActiveFile::VerifiedKeyWithExpiration
  class_attribute :verifier, default: defined?(Rails) ? Rails.application.message_verifier('ActiveFile') : nil

  def self.encode(key, expires_in: nil)
    verifier.generate([ key, expires_in ? Time.now.utc.advance(sec: expires_in) : nil ])
  end

  def self.decode(encoded_key)
    key, expires_at = verifier.verified(encoded_key)

    if key
      key if expires_at.nil? || Time.now.utc < expires_at
    end
  end
end
