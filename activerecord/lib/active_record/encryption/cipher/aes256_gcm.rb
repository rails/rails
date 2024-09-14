# frozen_string_literal: true

require "openssl"

module ActiveRecord
  module Encryption
    class Cipher
      # A 256-GCM cipher.
      #
      # By default it will use random initialization vectors. For deterministic encryption, it will use a SHA-256 hash of
      # the text to encrypt and the secret.
      #
      # See +Encryptor+
      class Aes256Gcm
        CIPHER_TYPE = "aes-256-gcm"

        class << self
          def key_length
            OpenSSL::Cipher.new(CIPHER_TYPE).key_len
          end

          def iv_length
            OpenSSL::Cipher.new(CIPHER_TYPE).iv_len
          end
        end

        # When iv not provided, it will generate a random iv on each encryption operation (default and
        # recommended operation)
        def initialize(secret, deterministic: false)
          @secret = secret
          @deterministic = deterministic
        end

        def encrypt(clear_text)
          # This code is extracted from +ActiveSupport::MessageEncryptor+. Not using it directly because we want to control
          # the message format and only serialize things once at the +ActiveRecord::Encryption::Message+ level. Also, this
          # cipher is prepared to deal with deterministic/non deterministic encryption modes.

          cipher = OpenSSL::Cipher.new(CIPHER_TYPE)
          cipher.encrypt
          cipher.key = @secret

          iv = generate_iv(cipher, clear_text)
          cipher.iv = iv

          encrypted_data = clear_text.empty? ? clear_text.dup : cipher.update(clear_text)
          encrypted_data << cipher.final

          ActiveRecord::Encryption::Message.new(payload: encrypted_data).tap do |message|
            message.headers.iv = iv
            message.headers.auth_tag = cipher.auth_tag
          end
        end

        def decrypt(encrypted_message)
          encrypted_data = encrypted_message.payload
          iv = encrypted_message.headers.iv
          auth_tag = encrypted_message.headers.auth_tag

          # Currently the OpenSSL bindings do not raise an error if auth_tag is
          # truncated, which would allow an attacker to easily forge it. See
          # https://github.com/ruby/openssl/issues/63
          raise ActiveRecord::Encryption::Errors::EncryptedContentIntegrity if auth_tag.nil? || auth_tag.bytes.length != 16

          cipher = OpenSSL::Cipher.new(CIPHER_TYPE)

          cipher.decrypt
          cipher.key = @secret
          cipher.iv = iv

          cipher.auth_tag = auth_tag
          cipher.auth_data = ""

          decrypted_data = encrypted_data.empty? ? encrypted_data : cipher.update(encrypted_data)
          decrypted_data << cipher.final

          decrypted_data
        rescue OpenSSL::Cipher::CipherError, TypeError, ArgumentError
          raise ActiveRecord::Encryption::Errors::Decryption
        end

        def inspect # :nodoc:
          "#<#{self.class.name}:#{'%#016x' % (object_id << 1)}>"
        end

        private
          def generate_iv(cipher, clear_text)
            if @deterministic
              generate_deterministic_iv(clear_text)
            else
              cipher.random_iv
            end
          end

          def generate_deterministic_iv(clear_text)
            OpenSSL::HMAC.digest(OpenSSL::Digest::SHA256.new, @secret, clear_text)[0, ActiveRecord::Encryption.cipher.iv_length]
          end
      end
    end
  end
end
