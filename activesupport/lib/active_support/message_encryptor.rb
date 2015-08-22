require 'openssl'
require 'base64'
require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/securerandom'
require 'active_support/core_ext/hash/keys'
require 'active_support/claims'
require 'active_support/message_verifier'
require 'active_support/encryptor/jwe'

module ActiveSupport
  # MessageEncryptor is a simple way to encrypt values which get stored
  # somewhere you don't trust.
  #
  # The resulting message is a JWE representation which is encrypted and
  # integrity protected.
  #
  # This can be used in situations similar to the <tt>MessageVerifier</tt>, but
  # where you don't want users to be able to determine the value of the payload.
  #
  #   salt  = SecureRandom.random_bytes(64)
  #   key   = ActiveSupport::KeyGenerator.new('password').generate_key(salt) # => "\x89\xE0\x156\xAC..."
  #   crypt = ActiveSupport::MessageEncryptor.new(key)                       # => #<ActiveSupport::MessageEncryptor ...>
  #   encrypted_data = crypt.encrypt_and_sign('my secret data')              # => "BAh7CEkiCHR5cAY6BkVUSSIISldFBjsAVEkiCGFsZwY7AF..."
  #   crypt.decrypt_and_verify(encrypted_data)                               # => "my secret data"
  class MessageEncryptor
    module NullSerializer #:nodoc:
      def self.load(value)
        value
      end

      def self.dump(value)
        value
      end
    end

    class InvalidMessage < StandardError; end
    class UnexpectedAlgorithm < StandardError; end
    class MalformedToken < StandardError; end

    OpenSSLCipherError = OpenSSL::Cipher::CipherError

    # Initialize a new MessageEncryptor. +secret+ must be at least as long as
    # the cipher key size. For the default 'aes-256-cbc' cipher, this is 256
    # bits. If you are using a user-entered secret, you can generate a suitable
    # key with <tt>OpenSSL::Digest::SHA256.new(user_secret).digest</tt> or
    # similar.
    #
    # ====Options
    #
    # * <tt>:enc</tt> - Encryption Algorithm Header Parameter. Content encryption
    #   algorithm used to perform authenticated encryption on the Plaintext to
    #   produce the Ciphertext and the Authentication Tag. Can be any value
    #   among these four: 'A256GCM', 'A128GCM', 'A256CBC-HS512', 'A128CBC-HS256'.
    #   Default is 'A256CBC-HS512'.
    # * <tt>:alg</tt> - Algorithm used to encrypt or determine the value of the
    #   Content Encryption Key. Only 'dir' is implemented as of now.
    # * <tt>:cipher</tt> - Cipher to use. Can be any cipher among these four:
    #   'aes-128-gcm', 'aes-256-gcm', 'aes-128-cbc', 'aes-256-cbc'. Default
    #   is 'aes-256-cbc'. Fill either +:enc+ or +:cipher+ but not both.
    #   Correspondence between them is as follows:
    #   'A256GCM' => 'aes-256-gcm', 'A128GCM' => 'aes-128-gcm',
    #   'A256CBC-HS512' => 'aes-256-cbc', 'A128CBC-HS256' => 'aes-128-cbc'.
    # * <tt>:serializer</tt> - Object serializer to use. Default is +Marshal+.
    #
    # ====Examples
    #
    # Create a +MessageEncryptor+ instance with valid +options+.
    #
    #   encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.hex(32), enc: 'A256GCM')
    #
    # Raises +UnexpectedAlgorithm+ if the algorithm given through +:alg+, +:enc+ or +:cipher+
    # is not implemented or is invalid.
    #
    #   encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.hex(32), enc: 'A192GCM')
    #   # raises ActiveSupport::MessageEncryptor::UnexpectedAlgorithm: Unknown Encryption Algorithm.
    #
    #   encryptor = ActiveSupport::MessageEncryptor.new(SecureRandom.hex(32), alg: 'A128GCMKW')
    #   # raises ActiveSupport::MessageEncryptor::UnexpectedAlgorithm: Unknown Encryption Algorithm.
    def initialize(secret, sign_secret = nil, **options)
      @options = options || {}
      @secret = secret
      @sign_secret = sign_secret || @secret
      @jwe = JWE.new(secret: @secret, **@options)
      @cipher = @jwe.cipher
      @serializer = @options[:serializer] || Marshal
    end

    # Generates an encrypted and integrity protected message fot the given
    # +value+ and +options+. AEAD (Authenticated Encryption with Associated Data)
    # algorithms are used to achieve this. e.g. AES Galois/Counter Mode (GCM) and
    # AES Cipher Block Chaining (CBC). The final message is a JWE (JSON Web
    # Encryption) Compact Serialization given by:
    # BASE64URL(UTF8(JWE Protected Header)) || '.' || BASE64URL(JWE Encrypted Key)
    # || '.' || BASE64URL(JWE Initialization Vector) || '.' || BASE64URL(JWE
    # Ciphertext) || '.' || BASE64URL(JWE Authentication Tag).
    #
    # JWE Protected Header - JSON object that contains the Header Parameters which
    # describe the operations applied to the Plaintext and additional properties of
    # the JWE. A JWE protected header with 'aes-256-gcm' AEAD algorithm and direct
    # encryption:
    #
    #   { 'typ' => 'JWT', 'alg' => 'dir', 'enc' => 'A256GCM' }
    #
    # JWE Encrypted Key -  Encrypted Content Encryption Key (CEK) value. CEK is
    # symmetric key for the AEAD algorithm used to encrypt the Plaintext. Is empty
    # octet sequence for direct encryption (+:alg+ => 'dir').
    #
    # JWE Initialization Vector - Initialization vector value used when encrypting
    # the plaintext.
    #
    # JWE Ciphertext - Ciphertext value resulting from authenticated encryption of the
    # plaintext with additional authenticated data.
    #
    # JWE Authentication Tag - Authentication Tag value resulting from authenticated
    # encryption of the plaintext with additional authenticated data.
    #
    # Standard JWE Specification:
    # https://tools.ietf.org/html/draft-ietf-jose-json-web-encryption-40
    #
    # Plaintext used for AEAD is the JWT Claims Set as explained in +MessageVerifier+.
    #
    # ==== Options
    #
    # * <tt>:expires_at</tt> - Explicit expiring time for the signed message.
    # * <tt>:expires_in</tt> - Relative time the message should
    #   expire after (e.g. 1.hour).
    # * <tt>:for</tt> - The signed message purpose confines usage to places with
    #   the same purpose. Defaults to a universally usable message.
    #
    # ==== Examples
    #
    # Messages can be encrypted and authenticated (AEAD) to ensure that confidential
    # data cannot be determined.
    #
    #   encryptor = ActiveSupport::MessageEncryptor.new SecureRandom.hex(32)
    #   encryptor.encrypt_and_sign('a secret message')
    #   # => "BAh7CEkiCHR5cAY6BkVUSSIISldFBjsAVEkiCGFsZwY7AFR..."
    #
    # Raises <tt>OpenSSL::Cipher::CipherError</tt> if the secret length is too
    # short.
    #
    #   ActiveSupport::MessageEncryptor.new(SecureRandom.hex(16)).encrypt_and_sign('data')
    #   # raises OpenSSL::Cipher::CipherError: key length too short
    #
    # Messages can be given a purpose to bump the security up some more.
    # This way evildoers can't reuse a message generated for the sign-up form
    # on any other page:
    #
    #   signup_message = encryptor.encrypt_and_sign('a secret message', for: 'signup_form')
    #   # => "BAh7CEkiCHR5cAY6BkVUSSIISldFBjsAVEkiCGFsZwY7AFR..."
    #
    #   encryptor.decrypt_and_verify(signup_message, for: 'signup_form')
    #   # => "a secret message"
    #
    # A message can also be given an expiration time with either +expires_in+
    # or +expires_at+. Useful when a message should not be accessible indefinitely.
    # The +expires_in+ option accepts a relative time, which is resolved to an
    # explicit expiry time, when the message is signed:
    #
    #   expiring_message = encryptor.encrypt_and_sign('a secret message', for: 'remember_me', expires_in: 1.hour)
    #   # => "BAh7CEkiCHR5cAY6BkVUSSIISldFBjsAVEkiCGFsZwY7AFR..."
    #
    #   # Within 1 hour...
    #   encryptor.decrypt_and_verify(expiring_message, for: 'remember_me')
    #   # => "a secret message"
    #
    #   # After 1 hour...
    #   encryptor.decrypt_and_verify(expiring_message, for: 'remember_me')
    #   # raises ActiveSupport::Claims::ExpiredClaims
    #
    # A message can also be set to expire at an explicit time with +expires_at+
    def encrypt_and_sign(value, options = {})
      claims = Claims.new(payload: value, **options)
      @jwe.encrypt claims.to_h
    end

    # Decodes the encrypted message using the +MessageEncryptor+'s secret. It is
    # the reverse of +encrypt_and_sign+. It also decodes legacy messages which are
    # outdated messages generated by +MessageEncryptor+ of the previous rails version.
    #
    #   encryptor = ActiveSupport::MessageEncryptor.new SecureRandom.hex(32)
    #   message = encryptor.encrypt_and_sign('a secret message', for: 'test', expires_in: 1.day)
    #
    #   # Within 1 day...
    #   encryptor.decrypt_and_verify(message, for: 'test') # => "a secret message"
    #
    #   legacy_message = "K3I2cERDcnBGK2I2aW5xMU5nY3h1VWdpM1U3TlJqNzRkdlgzeWlBVmNyUT0tLVZLbFk3WklQcWF3cEZhdlFXOTJ6emc9PQ==--243b5ce1ed05b021c8bb14489dcbf036e2ec53b6"
    #   encryptor.decrypt_and_verify(legacy_message) # => "a secret message"
    #
    # Raises +InvalidMessage+ if the message was not encrypted with the same key/secret.
    #
    #   other_encryptor = ActiveSupport::MessageEncryptor.new SecureRandom.hex(32)
    #   other_encryptor.decrypt_and_verify(message, for: 'test')
    #   # raises ActiveSupport::MessageEncryptor::InvalidMessage
    #
    # Raises +InvalidMessage+ if the encrypted message is tampered.
    #
    #   encryptor.decrypt_and_verify(tampered_message)
    #   # raises ActiveSupport::MessageEncryptor::InvalidMessage
    #
    # Raises +MalformedToken+ if the message is not in the JWE format.
    #
    #   encryptor.decrypt_and_verify('Message-having-invalid-JWE-format')
    #   # raises ActiveSupport::MessageEncryptor::MalformedToken: Invalid JWE Format.
    #
    # Raises +InvalidClaims+ if the message doesn't have the same purpose as that
    # given in the +options+.
    #
    #   encryptor.decrypt_and_verify(message, for: 'something_else')
    #   # raises ActiveSupport::Claims::InvalidClaims
    #
    # Raises +ExpiredClaims+ if the message is expired.
    #
    #   expired_message = encryptor.encrypt_and_sign('a secret message', expires_at: 1.day.ago)
    #   encryptor.decrypt_and_verify(expired_message)
    #   # raises ActiveSupport::Claims::ExpiredClaims
    def decrypt_and_verify(message, options = {})
      if legacy_message?(message)
        legacy_encryptor = LegacyMessageEncryptor.new(@secret, @sign_secret, @options)
        legacy_encryptor.decrypt_and_verify(message)
      else
        if message.count('.') == 4
          claims = @jwe.decrypt(message).symbolize_keys
          Claims.verify!(claims, options)
        else
          raise MalformedToken, 'Invalid JWE Format.'
        end
      end
    end

    private
      def legacy_message?(message)
        message.include?('--') && !message.include?('.')
      end
  end

  private
    class LegacyMessageEncryptor < MessageEncryptor # :nodoc:
      def initialize(secret, *signature_key_or_options)
        super
        @cipher = @options[:cipher] || 'aes-256-cbc'
        @verifier = ActiveSupport::LegacyMessageVerifier.new(@sign_secret, digest: @options[:digest] || 'SHA1', serializer: NullSerializer)
      end

      # Encrypt and sign a message. We need to sign the message in order to avoid
      # padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
      def encrypt_and_sign(value)
        @verifier.generate(_encrypt(value))
      end

      # Decrypt and verify a message. We need to verify the message in order to
      # avoid padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
      def decrypt_and_verify(value)
        _decrypt(@verifier.verify(value))
      end

      private
        def _encrypt(value)
          cipher = new_cipher
          cipher.encrypt
          cipher.key = @secret

          # Rely on OpenSSL for the initialization vector
          iv = cipher.random_iv

          encrypted_data = cipher.update(@serializer.dump(value))
          encrypted_data << cipher.final

          "#{::Base64.strict_encode64 encrypted_data}--#{::Base64.strict_encode64 iv}"
        end

        def _decrypt(encrypted_message)
          cipher = new_cipher
          encrypted_data, iv = encrypted_message.split('--').map { |v| ::Base64.strict_decode64(v) }

          cipher.decrypt
          cipher.key = @secret
          cipher.iv  = iv

          decrypted_data = cipher.update(encrypted_data)
          decrypted_data << cipher.final

          @serializer.load(decrypted_data)
        rescue OpenSSLCipherError, TypeError, ArgumentError
          raise InvalidMessage
        end

        def new_cipher
          OpenSSL::Cipher::Cipher.new(@cipher)
        end
    end
end
