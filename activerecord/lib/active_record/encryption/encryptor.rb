# frozen_string_literal: true

require "openssl"
require "zlib"
require "active_support/core_ext/numeric"

module ActiveRecord
  module Encryption
    # An encryptor exposes the encryption API that +ActiveRecord::Encryption::EncryptedAttributeType+
    # uses for encrypting and decrypting attribute values.
    #
    # It interacts with a +KeyProvider+ for getting the keys, and delegate to
    # +ActiveRecord::Encryption::Cipher+ the actual encryption algorithm.
    class Encryptor
      # Encrypts +clean_text+ and returns the encrypted result
      #
      # Internally, it will:
      #
      # 1. Create a new +ActiveRecord::Encryption::Message+
      # 2. Compress and encrypt +clean_text+ as the message payload
      # 3. Serialize it with +ActiveRecord::Encryption.message_serializer+ (+ActiveRecord::Encryption::SafeMarhsal+
      #    by default)
      # 4. Encode the result with Base 64
      #
      # === Options
      #
      # [:key_provider]
      #   Key provider to use for the encryption operation. It will default to
      #   +ActiveRecord::Encryption.key_provider+ when not provided
      #
      # [:cipher_options]
      #   +Cipher+-specific options that will be passed to the Cipher configured in
      #   +ActiveRecord::Encryption.cipher+
      def encrypt(clear_text, key_provider: default_key_provider, cipher_options: {})
        validate_payload_type(clear_text)
        serialize_message build_encrypted_message(clear_text, key_provider: key_provider, cipher_options: cipher_options)
      end

      # Decrypts a +clean_text+ and returns the result as clean text
      #
      # === Options
      #
      # [:key_provider]
      #   Key provider to use for the encryption operation. It will default to
      #   +ActiveRecord::Encryption.key_provider+ when not provided
      #
      # [:cipher_options]
      #   +Cipher+-specific options that will be passed to the Cipher configured in
      #   +ActiveRecord::Encryption.cipher+
      def decrypt(encrypted_text, key_provider: default_key_provider, cipher_options: {})
        message = deserialize_message(encrypted_text)
        keys = key_provider.decryption_keys(message)
        raise Errors::Decryption unless keys.present?
        uncompress_if_needed(cipher.decrypt(message, key: keys.collect(&:secret), **cipher_options), message.headers.compressed)
      rescue *(ENCODING_ERRORS + DECRYPT_ERRORS)
        raise Errors::Decryption
      end

      # Returns whether the text is encrypted or not
      def encrypted?(text)
        deserialize_message(text)
        true
      rescue Errors::Encoding, *DECRYPT_ERRORS
        false
      end

      private
        DECRYPT_ERRORS = [OpenSSL::Cipher::CipherError, Errors::EncryptedContentIntegrity, Errors::Decryption]
        ENCODING_ERRORS = [EncodingError, Errors::Encoding]
        THRESHOLD_TO_JUSTIFY_COMPRESSION = 140.bytes

        def default_key_provider
          ActiveRecord::Encryption.key_provider
        end

        def validate_payload_type(clear_text)
          unless clear_text.is_a?(String)
            raise ActiveRecord::Encryption::Errors::ForbiddenClass, "The encryptor can only encrypt string values (#{clear_text.class})"
          end
        end

        def cipher
          ActiveRecord::Encryption.cipher
        end

        def build_encrypted_message(clear_text, key_provider:, cipher_options:)
          key = key_provider.encryption_key

          clear_text, was_compressed = compress_if_worth_it(clear_text)
          cipher.encrypt(clear_text, key: key.secret, **cipher_options).tap do |message|
            message.headers.add(key.public_tags)
            message.headers.compressed = true if was_compressed
          end
        end

        def serialize_message(message)
          serializer.dump(message)
        end

        def deserialize_message(message)
          raise Errors::Encoding unless message.is_a?(String)
          serializer.load message
        rescue ArgumentError, TypeError, Errors::ForbiddenClass
          raise Errors::Encoding
        end

        def serializer
          ActiveRecord::Encryption.message_serializer
        end

        # Under certain threshold, ZIP compression is actually worse that not compressing
        def compress_if_worth_it(string)
          if string.bytesize > THRESHOLD_TO_JUSTIFY_COMPRESSION
            [compress(string), true]
          else
            [string, false]
          end
        end

        def compress(data)
          Zlib::Deflate.deflate(data).tap do |compressed_data|
            compressed_data.force_encoding(data.encoding)
          end
        end

        def uncompress_if_needed(data, compressed)
          if compressed
            uncompress(data)
          else
            data
          end
        end

        def uncompress(data)
          Zlib::Inflate.inflate(data).tap do |uncompressed_data|
            uncompressed_data.force_encoding(data.encoding)
          end
        end
    end
  end
end
