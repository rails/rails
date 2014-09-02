require 'base64'
require 'active_support/core_ext/object/blank'

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

  # PerishableEnvelope is used to envelop a serializer(like:Marshal, YAML or JSON) to provide the serializer ability to serialize Time(-like) Object and check the expiration when load it.
  class PerishableEnvelope # :nodoc:
    class ExpiredMessage < StandardError; end
    SIGNATURE = "\0"

    def initialize(serializer)
      @serializer = serializer
    end

    def dump(value, expiration=nil)
      if expiration.present?
        "#{SIGNATURE}--#{encode_expiration(expiration)}--#{@serializer.dump(value)}"
      else
        @serializer.dump(value)
      end
    end

    def load(value)
      if value.start_with?(SIGNATURE)
        values = value.split("--")
        values.shift
        expiration = values.shift
        raise ExpiredMessage if is_expired?(expiration)
        value = values.join("--")
      end
      @serializer.load(value)
    end

    private
    def encode_expiration(time)
      if time.respond_to?(:to_time)
        time.to_time.utc.iso8601
      else
        raise ArgumentError
      end
    end

    def is_expired?(timestamp)
      timestamp && Time.now.utc > Time.iso8601(timestamp)
    end
  end


  class MessageVerifier
    class InvalidSignature < StandardError; end
    ExpiredMessage = ActiveSupport::PerishableEnvelope::ExpiredMessage

    def initialize(secret, options = {})
      @secret = secret
      @digest = options[:digest] || 'SHA1'
      @serializer = PerishableEnvelope.new(options[:serializer] || Marshal)
    end

    def verify(signed_message)
      raise InvalidSignature if signed_message.blank?

      data, digest = signed_message.split("--")
      if data.present? && digest.present? && secure_compare(digest, generate_digest(data))
        begin
          @serializer.load(::Base64.strict_decode64(data))
        rescue ArgumentError => argument_error
          raise InvalidSignature if argument_error.message =~ %r{invalid base64}
          raise
        end
      else
        raise InvalidSignature
      end
    end

    def generate(value, expiration=nil)
      data = ::Base64.strict_encode64(@serializer.dump(value,expiration))
      "#{data}--#{generate_digest(data)}"
    end

    private
      # constant-time comparison algorithm to prevent timing attacks
      def secure_compare(a, b)
        return false unless a.bytesize == b.bytesize

        l = a.unpack "C#{a.bytesize}"

        res = 0
        b.each_byte { |byte| res |= byte ^ l.shift }
        res == 0
      end

      def generate_digest(data)
        require 'openssl' unless defined?(OpenSSL)
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest.const_get(@digest).new, @secret, data)
      end
  end
end
