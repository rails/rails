require 'openssl'
require 'active_support/base64'

module ActiveSupport
  # MessageEncryptor is a simple way to encrypt values which get stored somewhere
  # you don't trust.
  #
  # The cipher text and initialization vector are base64 encoded and returned to you.
  #
  # This can be used in situations similar to the <tt>MessageVerifier</tt>, but where you don't
  # want users to be able to determine the value of the payload.
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
    OpenSSLCipherError = OpenSSL::Cipher.const_defined?(:CipherError) ? OpenSSL::Cipher::CipherError : OpenSSL::CipherError

    def initialize(secret, options = {})
      unless options.is_a?(Hash)
        ActiveSupport::Deprecation.warn "The second parameter should be an options hash. Use :cipher => 'algorithm' to specify the cipher algorithm."
        options = { :cipher => options }
      end

      @secret = secret
      @cipher = options[:cipher] || 'aes-256-cbc'
      @verifier = MessageVerifier.new(@secret, :serializer => NullSerializer)
      @serializer = options[:serializer] || Marshal
    end

    def encrypt(value)
      ActiveSupport::Deprecation.warn "MessageEncryptor#encrypt is deprecated as it is not safe without a signature. " \
        "Please use MessageEncryptor#encrypt_and_sign instead."
      _encrypt(value)
    end

    def decrypt(value)
      ActiveSupport::Deprecation.warn "MessageEncryptor#decrypt is deprecated as it is not safe without a signature. " \
        "Please use MessageEncryptor#decrypt_and_verify instead."
      _decrypt(value)
    end

    # Encrypt and sign a message. We need to sign the message in order to avoid padding attacks.
    # Reference: http://www.limited-entropy.com/padding-oracle-attacks
    def encrypt_and_sign(value)
      verifier.generate(_encrypt(value))
    end

    # Decrypt and verify a message. We need to verify the message in order to avoid padding attacks.
    # Reference: http://www.limited-entropy.com/padding-oracle-attacks
    def decrypt_and_verify(value)
      _decrypt(verifier.verify(value))
    end

    private

    def _encrypt(value)
      cipher = new_cipher
      # Rely on OpenSSL for the initialization vector
      iv = cipher.random_iv

      cipher.encrypt
      cipher.key = @secret
      cipher.iv  = iv

      encrypted_data = cipher.update(@serializer.dump(value))
      encrypted_data << cipher.final

      [encrypted_data, iv].map {|v| ::Base64.strict_encode64(v)}.join("--")
    end

    def _decrypt(encrypted_message)
      cipher = new_cipher
      encrypted_data, iv = encrypted_message.split("--").map {|v| ::Base64.decode64(v)}

      cipher.decrypt
      cipher.key = @secret
      cipher.iv  = iv

      decrypted_data = cipher.update(encrypted_data)
      decrypted_data << cipher.final

      @serializer.load(decrypted_data)
    rescue OpenSSLCipherError, TypeError
      raise InvalidMessage
    end

    def new_cipher
      OpenSSL::Cipher::Cipher.new(@cipher)
    end

    def verifier
      @verifier
    end
  end
end
