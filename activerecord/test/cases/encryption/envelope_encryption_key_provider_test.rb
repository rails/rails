# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::EnvelopeEncryptionKeyProviderTest < ActiveRecord::EncryptionTestCase
  setup do
    @key_provider = ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
  end

  test "encryption_key returns random encryption keys" do
    keys = 5.times.collect { @key_provider.encryption_key }
    assert_equal 5, keys.group_by(&:secret).length
  end

  test "generate_random_encryption_key generates keys of 32 bytes" do
    assert_equal 32, @key_provider.encryption_key.secret.bytesize
  end

  test "generated random keys carry their secret encrypted with the master key" do
    key = @key_provider.encryption_key
    encrypted_secret = key.public_tags.encrypted_data_key
    assert_equal key.secret, ActiveRecord::Encryption.cipher.decrypt(encrypted_secret, key: @key_provider.active_primary_key.secret)
  end

  test "decryption_key_for returns the decryption key for a message that was encrypted with a generated encryption key" do
    key = @key_provider.encryption_key
    encrypted_encoded_message = ActiveRecord::Encryption.encryptor.encrypt("some message", key_provider: ActiveRecord::Encryption::KeyProvider.new(key))
    encrypted_message = ActiveRecord::Encryption.message_serializer.load encrypted_encoded_message
    assert_equal key.secret, @key_provider.decryption_keys(encrypted_message).first.secret
  end

  test "work with multiple keys when config.store_key_references is false" do
    ActiveRecord::Encryption.config.primary_key = ["key 1", "key 2"]

    assert_encryptor_works_with @key_provider
  end

  test "work with multiple keys when config.store_key_references is true" do
    ActiveRecord::Encryption.config.primary_key = ["key 1", "key 2"]
    ActiveRecord::Encryption.config.store_key_references = true

    assert_encryptor_works_with @key_provider
  end

  private
    def assert_multiple_primary_keys
      assert Rails.application.credentials.dig(:active_record_encryption, :primary_key).length > 1
    end
end
