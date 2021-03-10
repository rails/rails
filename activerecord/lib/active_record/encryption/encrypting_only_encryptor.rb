# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # An encryptor that can encrypt data but can't decrypt it
    class EncryptingOnlyEncryptor < Encryptor
      def decrypt(encrypted_text, key_provider: nil, cipher_options: {})
        encrypted_text
      end
    end
  end
end
