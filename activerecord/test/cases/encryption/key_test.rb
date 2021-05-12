# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::KeyTest < ActiveRecord::EncryptionTestCase
  test "A key can store a secret and public tags" do
    key = ActiveRecord::Encryption::Key.new("the secret")
    key.public_tags[:key] = "the key reference"

    assert_equal "the secret", key.secret
    assert_equal "the key reference", key.public_tags[:key]
  end

  test ".derive_from instantiates a key with its secret derived from the passed password" do
    assert_equal ActiveRecord::Encryption.key_generator.derive_key_from("some password"), ActiveRecord::Encryption::Key.derive_from("some password").secret
  end
end
