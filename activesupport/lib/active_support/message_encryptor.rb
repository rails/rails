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
    class InvalidMessage < StandardError; end
    OpenSSLCipherError = OpenSSL::Cipher.const_defined?(:CipherError) ? OpenSSL::Cipher::CipherError : OpenSSL::CipherError

    def initialize(secret, options = {})
      unless options.is_a?(Hash)
        ActiveSupport::Deprecation.warn "The second parameter should be an options hash. Use :cipher => 'algorithm' to specify the cipher algorithm."
        options = { :cipher => options }
      end
      
      @secret = secret
      @cipher = options[:cipher] || 'aes-256-cbc'
      @serializer = options[:serializer] || Marshal
    end

    def encrypt(value)
      cipher = new_cipher
      # Rely on OpenSSL for the initialization vector
      iv = cipher.random_iv

      cipher.encrypt
      cipher.key = @secret
      cipher.iv  = iv

      encrypted_data = cipher.update(@serializer.dump(value))
      encrypted_data << cipher.final

      [encrypted_data, iv].map {|v| ActiveSupport::Base64.encode64s(v)}.join("--")
    end

    def decrypt(encrypted_message)
      cipher = new_cipher
      encrypted_data, iv = encrypted_message.split("--").map {|v| ActiveSupport::Base64.decode64(v)}

      cipher.decrypt
      cipher.key = @secret
      cipher.iv  = iv

      decrypted_data = cipher.update(encrypted_data)
      decrypted_data << cipher.final

      @serializer.load(decrypted_data)
    rescue OpenSSLCipherError, TypeError
      raise InvalidMessage
    end

    def encrypt_and_sign(value)
      verifier.generate(encrypt(value))
    end

    def decrypt_and_verify(value)
      decrypt(verifier.verify(value))
    end



    private
      def new_cipher
        OpenSSL::Cipher::Cipher.new(@cipher)
      end

      def verifier
        MessageVerifier.new(@secret)
      end
  end
end
