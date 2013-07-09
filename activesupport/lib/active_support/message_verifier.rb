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
  # Expiration timestamps can also be encoded into the signature to make the
  # perishable.
  #
  #   @verifier.generate(@user.id, expires: 2.weeks.from_now)
  #
  # By default it uses Marshal to serialize the message. If you want to use
  # another serialization method, you can set the serializer in the options
  # hash upon initialization:
  #
  #   @verifier = ActiveSupport::MessageVerifier.new('s3Krit', serializer: YAML)
  class MessageVerifier
    class Error < StandardError; end
    class InvalidSignature < Error; end
    class Expired < Error; end

    def initialize(secret, options = {})
      @secret = secret
      @digest = options[:digest] || 'SHA1'
      @serializer = options[:serializer] || Marshal
    end

    def verify(signed_message)
      raise InvalidSignature if signed_message.blank?

      parts = signed_message.split("--")
      if parts.length == 3
        data, expires, digest = parts
      else
        data, digest = parts
        expires = nil
      end

      if data.present? && digest.present? && secure_compare(digest, generate_digest(data, expires))
        value = @serializer.load(::Base64.decode64(data))

        if expires
          if Time.at(expires.to_i) >= Time.now
            value
          else
            raise Expired
          end
        else
          value
        end
      else
        raise InvalidSignature
      end
    end

    def generate(value, options = {})
      data = ::Base64.strict_encode64(@serializer.dump(value))

      if options[:expires]
        "#{data}--#{options[:expires].to_i}--#{generate_digest(data, options[:expires].to_i)}"
      else
        "#{data}--#{generate_digest(data)}"
      end
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

      def generate_digest(data, expires = nil)
        require 'openssl' unless defined?(OpenSSL)
        data += expires.to_s if expires
        OpenSSL::HMAC.hexdigest(OpenSSL::Digest.const_get(@digest).new, @secret, data)
      end
  end
end
