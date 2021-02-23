module ActiveRecord
  module Encryption
    # An encryptor that won't decrypt or encrypt. It will just return the passed
    # values
    class NullEncryptor
      def encrypt(clean_text, key_provider: nil, cipher_options: {})
        clean_text
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
