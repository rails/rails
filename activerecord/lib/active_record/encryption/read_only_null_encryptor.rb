module ActiveRecord
  module Encryption
    # A +NullEncryptor+ that will raise an error when trying to encrypt data
    #
    # This is useful when you want to reveal ciphertexts for debugging purposes
    # and you want to make sure you won't overwrite any encryptable attribute with
    # the wrong content.
    class ReadOnlyNullEncryptor
      def encrypt(clean_text, key_provider: nil, cipher_options: {})
        raise Errors::Encryption, "This encryptor is read-only"
      end

      def decrypt(encrypted_text, key_provider: nil, cipher_options: {})
        encrypted_text
      end

      def encrypted?(text)
        false
      end
    end
  end
end
