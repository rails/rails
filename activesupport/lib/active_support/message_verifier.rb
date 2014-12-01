require 'base64'
require 'active_support/core_ext/object/blank'
require 'active_support/security_utils'

module ActiveSupport
  # +MessageVerifier+ makes it easy to generate and verify messages which are
  # signed to prevent tampering.
  #
  # This is useful for cases like remember-me tokens and auto-unsubscribe links
  # where the session store isn't suitable or available.
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
  # By default it uses Marshal to serialize the message. If you want to use
  # another serialization method, you can set the serializer in the options
  # hash upon initialization:
  #
  #   @verifier = ActiveSupport::MessageVerifier.new('s3Krit', serializer: YAML)
  class MessageVerifier
    class InvalidSignature < StandardError; end

    def initialize(secret, options = {})
      raise ArgumentError, 'Secret should not be nil.' unless secret
      @secret = secret
      @digest = options[:digest] || 'SHA1'
      @serializer = options[:serializer] || Marshal
    end

    def verify(signed_message)
      raise InvalidSignature if signed_message.blank?

      data, digest = signed_message.split("--")
      if data.present? && digest.present? && ActiveSupport::SecurityUtils.secure_compare(digest, generate_digest(data))
        begin
          @serializer.load(decode(data))
        rescue ArgumentError => argument_error
          raise InvalidSignature if argument_error.message =~ %r{invalid base64}
          raise
        end
      else
        raise InvalidSignature
      end
    end

    def generate(value)
      data = encode(@serializer.dump(value))
      "#{data}--#{generate_digest(data)}"
    end

    private
      def encode(data)
        ::Base64.strict_encode64(data)
      end

      def decode(data)
        ::Base64.strict_decode64(data)
      end

      def generate_digest(data)
        require 'openssl' unless defined?(OpenSSL)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest.const_get(@digest).new, @secret, data)
      end
  end
end
