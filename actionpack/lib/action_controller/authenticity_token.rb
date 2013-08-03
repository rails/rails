module ActionController
  class AuthenticityToken
    class << self
      LENGTH = 32

      def generate_masked(session)
        one_time_pad = SecureRandom.random_bytes(LENGTH)
        encrypted_csrf_token = xor_byte_strings(one_time_pad, master_csrf_token(session))
        masked_token = one_time_pad + encrypted_csrf_token
        Base64.strict_encode64(masked_token)
      end

      def valid?(session, encoded_masked_token, logger = nil)
        return false if encoded_masked_token.nil?

        masked_token = Base64.strict_decode64(encoded_masked_token)

        # See if it's actually a masked token or not. In order to
        # deploy this code, we should be able to handle any unmasked
        # tokens that we've issued without error.
        if masked_token.length == LENGTH
          # This is actually an unmasked token
          if logger
            logger.warn "The client is using an unmasked CSRF token. This " +
              "should only happen immediately after you upgrade to masked " +
              "tokens; if this persists, something is wrong."
          end

          masked_token == master_csrf_token(session)

        elsif masked_token.length == LENGTH * 2
          # Split the token into the one-time pad and the encrypted
          # value and decrypt it
          one_time_pad = masked_token[0...LENGTH]
          encrypted_csrf_token = masked_token[LENGTH..-1]
          csrf_token = xor_byte_strings(one_time_pad, encrypted_csrf_token)

          csrf_token == master_csrf_token(session)
        end
      end

      private

      def xor_byte_strings(s1, s2)
        s1.bytes.zip(s2.bytes).map { |(c1,c2)| c1 ^ c2 }.pack('c*')
      end

      def master_csrf_token(session)
        session[:_csrf_token] ||= SecureRandom.base64(LENGTH)
        Base64.strict_decode64(session[:_csrf_token])
      end
    end
  end
end
