# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # The algorithm used for encrypting and decrypting +Message+ objects.
    #
    # It uses AES-256-GCM. It will generate a random IV for non deterministic encryption (default)
    # or derive an initialization vector from the encrypted content for deterministic encryption.
    #
    # See +Cipher::Aes256Gcm+
    class Cipher
      DEFAULT_ENCODING = Encoding::UTF_8

      # Encrypts the provided text and return an encrypted +Message+
      def encrypt(clean_text, key:, deterministic: false)
        cipher_for(key, deterministic: deterministic).encrypt(clean_text).tap do |message|
          message.headers.encoding = clean_text.encoding.name unless clean_text.encoding == DEFAULT_ENCODING
        end
      end

      # Decrypt the provided +Message+
      #
      # When +key+ is an Array, it will try all the keys raising a
      # +ActiveRecord::Encryption::Errors::Decryption+ if none works
      def decrypt(encrypted_message, key:)
        try_to_decrypt_with_each(encrypted_message, keys: Array(key)).tap do |decrypted_text|
          decrypted_text.force_encoding(encrypted_message.headers.encoding || DEFAULT_ENCODING)
        end
      end

      def key_length
        Aes256Gcm.key_length
      end

      def iv_length
        Aes256Gcm.iv_length
      end

      private
        def try_to_decrypt_with_each(encrypted_text, keys:)
          keys.each.with_index do |key, index|
            return cipher_for(key).decrypt(encrypted_text)
          rescue ActiveRecord::Encryption::Errors::Decryption
            raise if index == keys.length - 1
          end
        end

        def cipher_for(secret, deterministic: false)
          Aes256Gcm.new(secret, deterministic: deterministic)
        end
    end
  end
end
