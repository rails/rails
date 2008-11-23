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
      data, digest = signed_message.split("--")
      if digest != generate_digest(data)
        raise InvalidSignature
      else
        Marshal.load(ActiveSupport::Base64.decode64(data))
      end
    end
    
    def generate(value)
      data = ActiveSupport::Base64.encode64s(Marshal.dump(value))
      "#{data}--#{generate_digest(data)}"
    end
    
    private
      def generate_digest(data)
        require 'openssl' unless defined?(OpenSSL)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest::Digest.new(@digest), @secret, data)
      end
  end
end
