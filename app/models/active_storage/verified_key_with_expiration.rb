class ActiveStorage::VerifiedKeyWithExpiration
  class << self
    def encode(key, expires_in: nil)
      ActiveStorage.verifier.generate([ key, expires_at(expires_in) ])
    end

    def decode(encoded_key)
      key, expires_at = ActiveStorage.verifier.verified(encoded_key)

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
