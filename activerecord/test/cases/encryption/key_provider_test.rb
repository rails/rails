# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::KeyProviderTest < ActiveRecord::TestCase
  setup do
    @message ||= ActiveRecord::Encryption::Message.new(payload: "some secret")
    @keys = build_keys(3)
    @key_provider = ActiveRecord::Encryption::KeyProvider.new(@keys)
  end

  test "serves a single key for encrypting and decrypting" do
    key = @keys.first
    key_provider = ActiveRecord::Encryption::KeyProvider.new(key)

    assert_equal key, key_provider.encryption_key
    assert_equal [ key_provider.encryption_key ], key_provider.decryption_keys(@message)
  end

  test "serves the first key for encrypting" do
    assert_equal @keys.first, @key_provider.encryption_key
  end

  test "when store_key_references is false, the encryption key contains a reference to the key itself" do
    assert_nil @key_provider.encryption_key.public_tags.encrypted_data_key_id
  end

  test "when store_key_references is true, the encryption key contains a reference to the key itself" do
    ActiveRecord::Encryption.config.store_key_references = true

    assert_equal @keys.first.id, @key_provider.encryption_key.public_tags.encrypted_data_key_id
  end

  test "when the message does not contain any key reference, it returns all the keys" do
    assert_equal @keys, @key_provider.decryption_keys(@message)
  end

  test "when the message to decrypt contains a reference to the key id, it will return an array only with that message" do
    target_key = @keys[1]

    @message.headers.encrypted_data_key_id = target_key.id

    assert_equal [target_key], @key_provider.decryption_keys(@message)
  end

  test "work with multiple keys when config.store_key_references is false" do
    ActiveRecord::Encryption.config.store_key_references = false

    assert_encryptor_works_with @key_provider
  end

  test "work with multiple keys when config.store_key_references is true" do
    ActiveRecord::Encryption.config.store_key_references = true

    assert_encryptor_works_with @key_provider
  end
end
