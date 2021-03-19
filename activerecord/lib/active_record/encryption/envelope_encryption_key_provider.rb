# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # Implements a simple envelope encryption approach where:
    #
    # * It generates a random data-encryption key for each encryption operation
    # * It stores the generated key along with the encrypted payload. It encrypts this key
    #   with the master key provided in the credential +active_record.encryption.master key+
    #
    # This provider can work with multiple master keys. It will use the first one for encrypting.
    #
    # When `config.store_key_references` is true, it will also store a reference to
    # the specific master key that was used to encrypt the data-encryption key. When not set,
    # it will try all the configured master keys looking for the right one, in order to
    # return the right decryption key.
    class EnvelopeEncryptionKeyProvider
      def encryption_key
        random_secret = generate_random_secret
        ActiveRecord::Encryption::Key.new(random_secret).tap do |key|
          key.public_tags.encrypted_data_key = encrypt_data_key(random_secret)
          key.public_tags.encrypted_data_key_id = active_primary_key.id if ActiveRecord::Encryption.config.store_key_references
        end
      end

      def decryption_keys(encrypted_message)
        secret = decrypt_data_key(encrypted_message)
        secret ? [ActiveRecord::Encryption::Key.new(secret)] : []
      end

      def active_primary_key
        @active_primary_key ||= primary_key_provider.encryption_key
      end

      private
        def encrypt_data_key(random_secret)
          ActiveRecord::Encryption.cipher.encrypt(random_secret, key: active_primary_key.secret)
        end

        def decrypt_data_key(encrypted_message)
          encrypted_data_key = encrypted_message.headers.encrypted_data_key
          key = primary_key_provider.decryption_keys(encrypted_message)&.collect(&:secret)
          ActiveRecord::Encryption.cipher.decrypt encrypted_data_key, key: key if key
        end

        def primary_key_provider
          @primary_key_provider ||= DerivedSecretKeyProvider.new(ActiveRecord::Encryption.config.primary_key)
        end

        def generate_random_secret
          ActiveRecord::Encryption.key_generator.generate_random_key
        end
    end
  end
end
