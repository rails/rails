class ActiveStorage::VerifiedKeyWithExpiration
  class_attribute :verifier, default: defined?(Rails) ? Rails.application.message_verifier("ActiveStorage") : nil

  class << self
    def encode(key, expires_in: nil)
      verifier.generate([ key, expires_at(expires_in) ])
    end

    def decode(encoded_key)
      key, expires_at = verifier.verified(encoded_key)

      key if key && fresh?(expires_at)
    end

    private
      def expires_at(expires_in)
        expires_in ? Time.now.utc.advance(seconds: expires_in) : nil
      end

      def fresh?(expires_at)
        expires_at.nil? || Time.now.utc < expires_at
      end
  end
end
