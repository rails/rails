# frozen_string_literal: true

require "openssl"
require "base64"
require_relative "core_ext/array/extract_options"
require_relative "message_verifier"
require_relative "messages/metadata"

module ActiveSupport
  # MessageEncryptor is a simple way to encrypt values which get stored
  # somewhere you don't trust.
  #
  # The cipher text and initialization vector are base64 encoded and returned
  # to you.
  #
  # This can be used in situations similar to the <tt>MessageVerifier</tt>, but
  # where you don't want users to be able to determine the value of the payload.
  #
  #   len   = ActiveSupport::MessageEncryptor.key_len
  #   salt  = SecureRandom.random_bytes(len)
  #   key   = ActiveSupport::KeyGenerator.new('password').generate_key(salt, len) # => "\x89\xE0\x156\xAC..."
  #   crypt = ActiveSupport::MessageEncryptor.new(key)                            # => #<ActiveSupport::MessageEncryptor ...>
  #   encrypted_data = crypt.encrypt_and_sign('my secret data')                   # => "NlFBTTMwOUV5UlA1QlNEN2xkY2d6eThYWWh..."
  #   crypt.decrypt_and_verify(encrypted_data)                                    # => "my secret data"
  #
  # === Confining messages to a specific purpose
  #
  # By default any message can be used throughout your app. But they can also be
  # confined to a specific +:purpose+.
  #
  #   token = crypt.encrypt_and_sign("this is the chair", purpose: :login)
  #
  # Then that same purpose must be passed when verifying to get the data back out:
  #
  #   crypt.decrypt_and_verify(token, purpose: :login)    # => "this is the chair"
  #   crypt.decrypt_and_verify(token, purpose: :shipping) # => nil
  #   crypt.decrypt_and_verify(token)                     # => nil
  #
  # Likewise, if a message has no purpose it won't be returned when verifying with
  # a specific purpose.
  #
  #   token = crypt.encrypt_and_sign("the conversation is lively")
  #   crypt.decrypt_and_verify(token, purpose: :scare_tactics) # => nil
  #   crypt.decrypt_and_verify(token)                          # => "the conversation is lively"
  #
  # === Making messages expire
  #
  # By default messages last forever and verifying one year from now will still
  # return the original value. But messages can be set to expire at a given
  # time with +:expires_in+ or +:expires_at+.
  #
  #   crypt.encrypt_and_sign(parcel, expires_in: 1.month)
  #   crypt.encrypt_and_sign(doowad, expires_at: Time.now.end_of_year)
  #
  # Then the messages can be verified and returned upto the expire time.
  # Thereafter, verifying returns +nil+.
  #
  # === Rotating keys
  #
  # This class also defines a +rotate+ method which can be used to rotate out
  # encryption keys no longer in use.
  #
  # This method is called with an options hash where a +:cipher+ option and
  # either a +:raw_key+ or +:secret+ option must be defined. If +:raw_key+ is
  # defined, it is used directly for the underlying encryption function. If
  # the +:secret+ option is defined, a +:salt+ option must also be defined and
  # a +KeyGenerator+ instance will be used to derive a key using +:salt+. When
  # +:secret+ is used, a +:key_generator+ option may also be defined allowing
  # for custom +KeyGenerator+ instances. If CBC encryption is used a
  # `:raw_signed_key` or a `:signed_salt` option must also be defined. A
  # +:digest+ may also be defined when using CBC encryption. This method can be
  # called multiple times and new encryptor instances will be added to the
  # rotation stack on each call.
  #
  #   # Specifying the key used for encryption
  #   crypt.rotate raw_key: old_aead_key, cipher: "aes-256-gcm"
  #   crypt.rotate raw_key: old_cbc_key, raw_signed_key: old_cbc_sign_key, cipher: "aes-256-cbc", digest: "SHA1"
  #
  #   # Using a KeyGenerator instance with a secret and salt(s)
  #   crypt.rotate secret: old_aead_secret, salt: old_aead_salt, cipher: "aes-256-gcm"
  #   crypt.rotate secret: old_cbc_secret, salt: old_cbc_salt, signed_salt: old_cbc_signed_salt, cipher: "aes-256-cbc", digest: "SHA1"
  #
  #   # Specifying the key generator instance
  #   crypt.rotate key_generator: old_key_gen, salt: old_salt, cipher: "aes-256-gcm"
  class MessageEncryptor
    prepend Messages::Rotator::Encryptor

    class << self
      attr_accessor :use_authenticated_message_encryption #:nodoc:

      def default_cipher #:nodoc:
        if use_authenticated_message_encryption
          "aes-256-gcm"
        else
          "aes-256-cbc"
        end
      end
    end

    module NullSerializer #:nodoc:
      def self.load(value)
        value
      end

      def self.dump(value)
        value
      end
    end

    module NullVerifier #:nodoc:
      def self.verify(value)
        value
      end

      def self.generate(value)
        value
      end
    end

    class InvalidMessage < StandardError; end
    OpenSSLCipherError = OpenSSL::Cipher::CipherError

    # Initialize a new MessageEncryptor. +secret+ must be at least as long as
    # the cipher key size. For the default 'aes-256-gcm' cipher, this is 256
    # bits. If you are using a user-entered secret, you can generate a suitable
    # key by using <tt>ActiveSupport::KeyGenerator</tt> or a similar key
    # derivation function.
    #
    # First additional parameter is used as the signature key for +MessageVerifier+.
    # This allows you to specify keys to encrypt and sign data.
    #
    #    ActiveSupport::MessageEncryptor.new('secret', 'signature_secret')
    #
    # Options:
    # * <tt>:cipher</tt>     - Cipher to use. Can be any cipher returned by
    #   <tt>OpenSSL::Cipher.ciphers</tt>. Default is 'aes-256-gcm'.
    # * <tt>:digest</tt> - String of digest to use for signing. Default is
    #   +SHA1+. Ignored when using an AEAD cipher like 'aes-256-gcm'.
    # * <tt>:serializer</tt> - Object serializer to use. Default is +Marshal+.
    def initialize(secret, *signature_key_or_options)
      options = signature_key_or_options.extract_options!
      sign_secret = signature_key_or_options.first
      @secret = secret
      @sign_secret = sign_secret
      @cipher = options[:cipher] || self.class.default_cipher
      @digest = options[:digest] || "SHA1" unless aead_mode?
      @verifier = resolve_verifier
      @serializer = options[:serializer] || Marshal
    end

    # Encrypt and sign a message. We need to sign the message in order to avoid
    # padding attacks. Reference: https://www.limited-entropy.com/padding-oracle-attacks/.
    def encrypt_and_sign(value, expires_at: nil, expires_in: nil, purpose: nil)
      verifier.generate(_encrypt(value, expires_at: expires_at, expires_in: expires_in, purpose: purpose))
    end

    # Decrypt and verify a message. We need to verify the message in order to
    # avoid padding attacks. Reference: https://www.limited-entropy.com/padding-oracle-attacks/.
    def decrypt_and_verify(data, purpose: nil, **)
      _decrypt(verifier.verify(data), purpose)
    end

    # Given a cipher, returns the key length of the cipher to help generate the key of desired size
    def self.key_len(cipher = default_cipher)
      OpenSSL::Cipher.new(cipher).key_len
    end

    private
      def _encrypt(value, **metadata_options)
        cipher = new_cipher
        cipher.encrypt
        cipher.key = @secret

        # Rely on OpenSSL for the initialization vector
        iv = cipher.random_iv
        cipher.auth_data = "" if aead_mode?

        encrypted_data = cipher.update(Messages::Metadata.wrap(@serializer.dump(value), metadata_options))
        encrypted_data << cipher.final

        blob = "#{::Base64.strict_encode64 encrypted_data}--#{::Base64.strict_encode64 iv}"
        blob = "#{blob}--#{::Base64.strict_encode64 cipher.auth_tag}" if aead_mode?
        blob
      end

      def _decrypt(encrypted_message, purpose)
        cipher = new_cipher
        encrypted_data, iv, auth_tag = encrypted_message.split("--".freeze).map { |v| ::Base64.strict_decode64(v) }

        # Currently the OpenSSL bindings do not raise an error if auth_tag is
        # truncated, which would allow an attacker to easily forge it. See
        # https://github.com/ruby/openssl/issues/63
        raise InvalidMessage if aead_mode? && (auth_tag.nil? || auth_tag.bytes.length != 16)

        cipher.decrypt
        cipher.key = @secret
        cipher.iv  = iv
        if aead_mode?
          cipher.auth_tag = auth_tag
          cipher.auth_data = ""
        end

        decrypted_data = cipher.update(encrypted_data)
        decrypted_data << cipher.final

        message = Messages::Metadata.verify(decrypted_data, purpose)
        @serializer.load(message) if message
      rescue OpenSSLCipherError, TypeError, ArgumentError
        raise InvalidMessage
      end

      def new_cipher
        OpenSSL::Cipher.new(@cipher)
      end

      def verifier
        @verifier
      end

      def aead_mode?
        @aead_mode ||= new_cipher.authenticated?
      end

      def resolve_verifier
        if aead_mode?
          NullVerifier
        else
          MessageVerifier.new(@sign_secret || @secret, digest: @digest, serializer: NullSerializer)
        end
      end
  end
end
