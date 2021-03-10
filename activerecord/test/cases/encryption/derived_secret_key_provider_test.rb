# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::DerivedSecretKeyProviderTest < ActiveRecord::TestCase
  setup do
    @message ||= ActiveRecord::Encryption::Message.new(payload: "some secret")
    @keys = build_keys(3)
    @key_provider = ActiveRecord::Encryption::KeyProvider.new(@keys)
  end

  test "will derive a key with the right length from the given password" do
    key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new("some password")
    key = key_provider.encryption_key

    assert_equal [ key ], key_provider.decryption_keys(ActiveRecord::Encryption::Message.new(payload: "some secret"))
    assert_equal ActiveRecord::Encryption.cipher.key_length, key.secret.bytesize
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
