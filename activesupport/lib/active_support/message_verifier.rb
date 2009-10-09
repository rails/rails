module ActiveSupport
  # MessageVerifier makes it easy to generate and verify messages which are signed
  # to prevent tampering.
  # 
  # This is useful for cases like remember-me tokens and auto-unsubscribe links where the
  # session store isn't suitable or available.
  #
  # Remember Me:
  #   cookies[:remember_me] = @verifier.generate([@user.id, 2.weeks.from_now])
  # 
  # In the authentication filter:
  #
  #   id, time = @verifier.verify(cookies[:remember_me])
  #   if time < Time.now
  #     self.current_user = User.find(id)
  #   end
  # 
  class MessageVerifier
    class InvalidSignature < StandardError; end
    
    def initialize(secret, digest = 'SHA1')
      @secret = secret
      @digest = digest
    end
    
    def verify(signed_message)
      raise InvalidSignature if signed_message.blank?

      data, digest = signed_message.split("--")
      if data.present? && digest.present? && secure_compare(digest, generate_digest(data))
        Marshal.load(ActiveSupport::Base64.decode64(data))
      else
        raise InvalidSignature
      end
    end
    
    def generate(value)
      data = ActiveSupport::Base64.encode64s(Marshal.dump(value))
      "#{data}--#{generate_digest(data)}"
    end
    
    private
      if "foo".respond_to?(:force_encoding)
        # constant-time comparison algorithm to prevent timing attacks
        def secure_compare(a, b)
          a = a.dup.force_encoding(Encoding::BINARY)
          b = b.dup.force_encoding(Encoding::BINARY)

          if a.length == b.length
            result = 0
            for i in 0..(a.length - 1)
              result |= a[i].ord ^ b[i].ord
            end
            result == 0
          else
            false
          end
        end
      else
        # For <= 1.8.6
        def secure_compare(a, b)
          if a.length == b.length
            result = 0
            for i in 0..(a.length - 1)
              result |= a[i] ^ b[i]
            end
            result == 0
          else
            false
          end
        end
      end

      def generate_digest(data)
        require 'openssl' unless defined?(OpenSSL)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new(@digest), @secret, data)
      end
  end
end
