require 'openssl'
require 'base64'

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
  #   key = OpenSSL::Digest::SHA256.new('password').digest        # => "\x89\xE0\x156\xAC..."
  #   crypt = ActiveSupport::MessageEncryptor.new(key)            # => #<ActiveSupport::MessageEncryptor ...>
  #   encrypted_data = crypt.encrypt_and_sign('my secret data')   # => "NlFBTTMwOUV5UlA1QlNEN2xkY2d6eThYWWh..."
  #   crypt.decrypt_and_verify(encrypted_data)                    # => "my secret data"
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

    # Initialize a new MessageEncryptor. +secret+ must be at least as long as
    # the cipher key size. For the default 'aes-256-cbc' cipher, this is 256
    # bits. If you are using a user-entered secret, you can generate a suitable
    # key with <tt>OpenSSL::Digest::SHA256.new(user_secret).digest</tt> or
    # similar.
    #
    # Options:
    # * <tt>:cipher</tt>     - Cipher to use. Can be any cipher returned by
    #   <tt>OpenSSL::Cipher.ciphers</tt>. Default is 'aes-256-cbc'.
    # * <tt>:serializer</tt> - Object serializer to use. Default is +Marshal+.
    def initialize(secret, options = {})
      @secret = secret
      @cipher = options[:cipher] || 'aes-256-cbc'
      @verifier = MessageVerifier.new(@secret, :serializer => NullSerializer)
      @serializer = options[:serializer] || Marshal
    end

    # Encrypt and sign a message. We need to sign the message in order to avoid
    # padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
    def encrypt_and_sign(value)
      verifier.generate(_encrypt(value))
    end

    # Decrypt and verify a message. We need to verify the message in order to
    # avoid padding attacks. Reference: http://www.limited-entropy.com/padding-oracle-attacks.
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
