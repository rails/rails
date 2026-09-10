# frozen_string_literal: true

require "openssl"
require "base64"
require "active_support/core_ext/object/blank"
require "active_support/inspect_backport"
require "active_support/security_utils"
require "active_support/messages/codec"
require "active_support/messages/rotator"

module ActiveSupport
  # = Active Support Message Verifier
  #
  # +MessageVerifier+ makes it easy to generate and verify messages which are
  # signed to prevent tampering.
  #
  # In a \Rails application, you can use +Rails.application.message_verifier+
  # to manage unique instances of verifiers for each use case.
  # {Learn more}[link:classes/Rails/Application.html#method-i-message_verifier].
  #
  # This is useful for cases like remember-me tokens and auto-unsubscribe links
  # where the session store isn't suitable or available.
  #
  # First, generate a signed message:
  #   cookies[:remember_me] = Rails.application.message_verifier(:remember_me).generate([@user.id, 2.weeks.from_now])
  #
  # Later verify that message:
  #
  #   id, time = Rails.application.message_verifier(:remember_me).verify(cookies[:remember_me])
  #   if time.future?
  #     self.current_user = User.find(id)
  #   end
  #
  # === Signing is not encryption
  #
  # The signed messages are not encrypted. The payload is merely encoded (Base64 by default) and can be decoded by
  # anyone. The signature is just assuring that the message wasn't tampered with. For example:
  #
  #     message = Rails.application.message_verifier('my_purpose').generate('never put secrets here')
  #     # => "BAhJIhtuZXZlciBwdXQgc2VjcmV0cyBoZXJlBjoGRVQ=--a0c1c0827919da5e949e989c971249355735e140"
  #     Base64.decode64(message.split("--").first) # no key needed
  #     # => 'never put secrets here'
  #
  # If you also need to encrypt the contents, you must use ActiveSupport::MessageEncryptor instead.
  #
  # === Confine messages to a specific purpose
  #
  # It's not recommended to use the same verifier for different purposes in your application.
  # Doing so could allow a malicious actor to re-use a signed message to perform an unauthorized
  # action.
  # You can reduce this risk by confining signed messages to a specific +:purpose+.
  #
  #   token = @verifier.generate("signed message", purpose: :login)
  #
  # Then that same purpose must be passed when verifying to get the data back out:
  #
  #   @verifier.verified(token, purpose: :login)    # => "signed message"
  #   @verifier.verified(token, purpose: :shipping) # => nil
  #   @verifier.verified(token)                     # => nil
  #
  #   @verifier.verify(token, purpose: :login)      # => "signed message"
  #   @verifier.verify(token, purpose: :shipping)   # => raises ActiveSupport::MessageVerifier::InvalidSignature
  #   @verifier.verify(token)                       # => raises ActiveSupport::MessageVerifier::InvalidSignature
  #
  # Likewise, if a message has no purpose it won't be returned when verifying with
  # a specific purpose.
  #
  #   token = @verifier.generate("signed message")
  #   @verifier.verified(token, purpose: :redirect) # => nil
  #   @verifier.verified(token)                     # => "signed message"
  #
  #   @verifier.verify(token, purpose: :redirect)   # => raises ActiveSupport::MessageVerifier::InvalidSignature
  #   @verifier.verify(token)                       # => "signed message"
  #
  # === Expiring messages
  #
  # By default messages last forever and verifying one year from now will still
  # return the original value. But messages can be set to expire at a given
  # time with +:expires_in+ or +:expires_at+.
  #
  #   @verifier.generate("signed message", expires_in: 1.month)
  #   @verifier.generate("signed message", expires_at: Time.now.end_of_year)
  #
  # Messages can then be verified and returned until expiry.
  # Thereafter, the +verified+ method returns +nil+ while +verify+ raises
  # +ActiveSupport::MessageVerifier::InvalidSignature+.
  #
  # === Rotating keys
  #
  # MessageVerifier also supports rotating out old configurations by falling
  # back to a stack of verifiers. Call +rotate+ to build and add a verifier so
  # either +verified+ or +verify+ will also try verifying with the fallback.
  #
  # By default any rotated verifiers use the values of the primary
  # verifier unless specified otherwise.
  #
  # You'd give your verifier the new defaults:
  #
  #   verifier = ActiveSupport::MessageVerifier.new(@secret, digest: "SHA512", serializer: JSON)
  #
  # Then gradually rotate the old values out by adding them as fallbacks. Any message
  # generated with the old values will then work until the rotation is removed.
  #
  #   verifier.rotate(old_secret)          # Fallback to an old secret instead of @secret.
  #   verifier.rotate(digest: "SHA256")    # Fallback to an old digest instead of SHA512.
  #   verifier.rotate(serializer: Marshal) # Fallback to an old serializer instead of JSON.
  #
  # Though the above would most likely be combined into one rotation:
  #
  #   verifier.rotate(old_secret, digest: "SHA256", serializer: Marshal)
  class MessageVerifier < Messages::Codec
    prepend Messages::Rotator

    class InvalidSignature < StandardError; end

    SEPARATOR = "--" # :nodoc:
    SEPARATOR_LENGTH = SEPARATOR.length # :nodoc:

    # Initialize a new MessageVerifier with a secret for the signature.
    #
    # ==== Options
    #
    # [+:digest+]
    #   Digest used for signing. The default is <tt>"SHA1"</tt>. See
    #   +OpenSSL::Digest+ for alternatives.
    #
    # [+:serializer+]
    #   The serializer used to serialize message data. You can specify any
    #   object that responds to +dump+ and +load+, or you can choose from
    #   several preconfigured serializers: +:marshal+, +:json_allow_marshal+,
    #   +:json+, +:message_pack_allow_marshal+, +:message_pack+.
    #
    #   The preconfigured serializers include a fallback mechanism to support
    #   multiple deserialization formats. For example, the +:marshal+ serializer
    #   will serialize using +Marshal+, but can deserialize using +Marshal+,
    #   ActiveSupport::JSON, or ActiveSupport::MessagePack. This makes it easy
    #   to migrate between serializers.
    #
    #   The +:marshal+, +:json_allow_marshal+, and +:message_pack_allow_marshal+
    #   serializers support deserializing using +Marshal+, but the others do
    #   not. Beware that +Marshal+ is a potential vector for deserialization
    #   attacks in cases where a message signing secret has been leaked. <em>If
    #   possible, choose a serializer that does not support +Marshal+.</em>
    #
    #   The +:message_pack+ and +:message_pack_allow_marshal+ serializers use
    #   ActiveSupport::MessagePack, which can roundtrip some Ruby types that are
    #   not supported by JSON, and may provide improved performance. However,
    #   these require the +msgpack+ gem.
    #
    #   When using \Rails, the default depends on +config.active_support.message_serializer+.
    #   Otherwise, the default is +:marshal+.
    #
    # [+:url_safe+]
    #   By default, MessageVerifier generates RFC 4648 compliant strings which are
    #   not URL-safe. In other words, they can contain "+" and "/". If you want to
    #   generate URL-safe strings (in compliance with "Base 64 Encoding with URL
    #   and Filename Safe Alphabet" in RFC 4648), you can pass +true+.
    #   Note that MessageVerifier will always accept both URL-safe and URL-unsafe
    #   encoded messages, to allow a smooth transition between the two settings.
    #
    # [+:force_legacy_metadata_serializer+]
    #   Whether to use the legacy metadata serializer, which serializes the
    #   message first, then wraps it in an envelope which is also serialized. This
    #   was the default in \Rails 7.0 and below.
    #
    #   If you don't pass a truthy value, the default is set using
    #   +config.active_support.use_message_serializer_for_metadata+.
    def initialize(secret, **options)
      raise ArgumentError, "Secret should not be nil." unless secret
      super(**options)
      @secret = secret
      @digest = options[:digest]&.to_s || "SHA1"
    end

    # Checks if a signed message could have been generated by signing an object
    # with the +MessageVerifier+'s secret.
    #
    #   verifier = ActiveSupport::MessageVerifier.new("secret")
    #   signed_message = verifier.generate("signed message")
    #   verifier.valid_message?(signed_message) # => true
    #
    #   tampered_message = signed_message.chop # editing the message invalidates the signature
    #   verifier.valid_message?(tampered_message) # => false
    def valid_message?(message)
      !!catch_and_ignore(:invalid_message_format) { extract_encoded(message) }
    end

    # Decodes the signed message using the +MessageVerifier+'s secret.
    #
    #   verifier = ActiveSupport::MessageVerifier.new("secret")
    #
    #   signed_message = verifier.generate("signed message")
    #   verifier.verified(signed_message) # => "signed message"
    #
    # Returns +nil+ if the message was not signed with the same secret.
    #
    #   other_verifier = ActiveSupport::MessageVerifier.new("different_secret")
    #   other_verifier.verified(signed_message) # => nil
    #
    # Returns +nil+ if the message is not Base64-encoded.
    #
    #   invalid_message = "f--46a0120593880c733a53b6dad75b42ddc1c8996d"
    #   verifier.verified(invalid_message) # => nil
    #
    # Raises any error raised while decoding the signed message.
    #
    #   incompatible_message = "test--dad7b06c94abba8d46a15fafaef56c327665d5ff"
    #   verifier.verified(incompatible_message) # => TypeError: incompatible marshal file format
    #
    # ==== Options
    #
    # [+:purpose+]
    #   The purpose that the message was generated with. If the purpose does not
    #   match, +verified+ will return +nil+.
    #
    #     message = verifier.generate("hello", purpose: "greeting")
    #     verifier.verified(message, purpose: "greeting") # => "hello"
    #     verifier.verified(message, purpose: "chatting") # => nil
    #     verifier.verified(message)                      # => nil
    #
    #     message = verifier.generate("bye")
    #     verifier.verified(message)                      # => "bye"
    #     verifier.verified(message, purpose: "greeting") # => nil
    #
    def verified(message, **options)
      catch_and_ignore :invalid_message_format do
        catch_and_raise :invalid_message_serialization do
          catch_and_ignore :invalid_message_content do
            read_message(message, **options)
          end
        end
      end
    end

    # Decodes the signed message using the +MessageVerifier+'s secret.
    #
    #   verifier = ActiveSupport::MessageVerifier.new("secret")
    #   signed_message = verifier.generate("signed message")
    #
    #   verifier.verify(signed_message) # => "signed message"
    #
    # Raises +InvalidSignature+ if the message was not signed with the same
    # secret or was not Base64-encoded.
    #
    #   other_verifier = ActiveSupport::MessageVerifier.new("different_secret")
    #   other_verifier.verify(signed_message) # => ActiveSupport::MessageVerifier::InvalidSignature
    #
    # ==== Options
    #
    # [+:purpose+]
    #   The purpose that the message was generated with. If the purpose does not
    #   match, +verify+ will raise ActiveSupport::MessageVerifier::InvalidSignature.
    #
    #     message = verifier.generate("hello", purpose: "greeting")
    #     verifier.verify(message, purpose: "greeting") # => "hello"
    #     verifier.verify(message, purpose: "chatting") # => raises InvalidSignature
    #     verifier.verify(message)                      # => raises InvalidSignature
    #
    #     message = verifier.generate("bye")
    #     verifier.verify(message)                      # => "bye"
    #     verifier.verify(message, purpose: "greeting") # => raises InvalidSignature
    #
    def verify(message, **options)
      catch_and_raise :invalid_message_format, as: InvalidSignature do
        catch_and_raise :invalid_message_serialization do
          catch_and_raise :invalid_message_content, as: InvalidSignature do
            read_message(message, **options)
          end
        end
      end
    end

    # Generates a signed message for the provided value.
    #
    # The message is signed with the +MessageVerifier+'s secret.
    # Returns Base64-encoded message joined with the generated signature.
    #
    #   verifier = ActiveSupport::MessageVerifier.new("secret")
    #   verifier.generate("signed message") # => "BAhJIhNzaWduZWQgbWVzc2FnZQY6BkVU--f67d5f27c3ee0b8483cebf2103757455e947493b"
    #
    # ==== Options
    #
    # [+:expires_at+]
    #   The datetime at which the message expires. After this datetime,
    #   verification of the message will fail.
    #
    #     message = verifier.generate("hello", expires_at: Time.now.tomorrow)
    #     verifier.verified(message) # => "hello"
    #     # 24 hours later...
    #     verifier.verified(message) # => nil
    #     verifier.verify(message)   # => raises ActiveSupport::MessageVerifier::InvalidSignature
    #
    # [+:expires_in+]
    #   The duration for which the message is valid. After this duration has
    #   elapsed, verification of the message will fail.
    #
    #     message = verifier.generate("hello", expires_in: 24.hours)
    #     verifier.verified(message) # => "hello"
    #     # 24 hours later...
    #     verifier.verified(message) # => nil
    #     verifier.verify(message)   # => raises ActiveSupport::MessageVerifier::InvalidSignature
    #
    # [+:purpose+]
    #   The purpose of the message. If specified, the same purpose must be
    #   specified when verifying the message; otherwise, verification will fail.
    #   (See #verified and #verify.)
    def generate(value, **options)
      create_message(value, **options)
    end

    def create_message(value, **options) # :nodoc:
      sign_encoded(encode(serialize_with_metadata(value, **options)))
    end

    def read_message(message, **options) # :nodoc:
      deserialize_with_metadata(decode(extract_encoded(message)), **options)
    end

    ActiveSupport::InspectBackport.apply(self)

    private
      def instance_variables_to_inspect
        [].freeze
      end

      def decode(encoded, url_safe: @url_safe)
        catch :invalid_message_format do
          return super
        end
        super(encoded, url_safe: !url_safe)
      end

      def sign_encoded(encoded)
        digest = generate_digest(encoded)
        encoded << SEPARATOR << digest
      end

      def extract_encoded(signed)
        if signed.nil? || !signed.valid_encoding?
          throw :invalid_message_format, "invalid message string"
        end

        if separator_index = separator_index_for(signed)
          encoded = signed[0, separator_index]
          digest = signed[separator_index + SEPARATOR_LENGTH, digest_length_in_hex]
        end

        unless digest_matches_data?(digest, encoded)
          throw :invalid_message_format, "mismatched digest"
        end

        encoded
      end

      def generate_digest(data)
        OpenSSL::HMAC.hexdigest(@digest, @secret, data)
      end

      def digest_length_in_hex
        # In hexadecimal (AKA base16) it takes 4 bits to represent a character,
        # hence we multiply the digest's length (in bytes) by 8 to get it in
        # bits and divide by 4 to get its number of characters it hex. Well, 8
        # divided by 4 is 2.
        @digest_length_in_hex ||= OpenSSL::Digest.new(@digest).digest_length * 2
      end

      def separator_at?(signed_message, index)
        signed_message[index, SEPARATOR_LENGTH] == SEPARATOR
      end

      def separator_index_for(signed_message)
        index = signed_message.length - digest_length_in_hex - SEPARATOR_LENGTH
        index unless index.negative? || !separator_at?(signed_message, index)
      end

      def digest_matches_data?(digest, data)
        data.present? && digest.present? && ActiveSupport::SecurityUtils.secure_compare(digest, generate_digest(data))
      end
  end
end
