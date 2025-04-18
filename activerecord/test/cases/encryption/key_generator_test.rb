# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::KeyGeneratorTest < ActiveRecord::EncryptionTestCase
  setup do
    @generator = ActiveRecord::Encryption::KeyGenerator.new
  end

  test "generate_random_key generates random keys with the cipher key length by default" do
    assert_not_equal @generator.generate_random_key, @generator.generate_random_key
    assert_equal ActiveRecord::Encryption.cipher.key_length, @generator.generate_random_key.bytesize
  end

  test "generate_random_key generates random keys with a custom length" do
    assert_not_equal @generator.generate_random_key(length: 10), @generator.generate_random_key(length: 10)
    assert_equal 10, @generator.generate_random_key(length: 10).bytesize
  end

  test "generate_random_hex_key generates random hexadecimal keys with the cipher key length by default" do
    assert_not_equal @generator.generate_random_hex_key, @generator.generate_random_hex_key
    assert_equal ActiveRecord::Encryption.cipher.key_length, [ @generator.generate_random_hex_key ].pack("H*").bytesize
  end

  test "generate_random_hex_key generates random hexadecimal keys with a custom length" do
    assert_not_equal @generator.generate_random_hex_key(length: 10), @generator.generate_random_hex_key(length: 10)
    assert_equal 10, [ @generator.generate_random_hex_key(length: 10) ].pack("H*").bytesize
  end

  test "derive keys using the configured digest algorithm" do
    assert_derive_key "some secret", digest_class: OpenSSL::Digest::SHA1
    assert_derive_key "some secret", digest_class: OpenSSL::Digest::SHA256
  end

  test "derive_key derives a key with from the provided password with the cipher key length by default" do
    assert_equal @generator.derive_key_from("some password"), @generator.derive_key_from("some password")
    assert_not_equal @generator.derive_key_from("some password"), @generator.derive_key_from("some other password")
    assert_equal ActiveRecord::Encryption.cipher.key_length, @generator.derive_key_from("some password").length
  end

  test "derive_key derives a key with a custom length" do
    assert_equal @generator.derive_key_from("some password", length: 12), @generator.derive_key_from("some password", length: 12)
    assert_not_equal @generator.derive_key_from("some password", length: 12), @generator.derive_key_from("some other password", length: 12)
    assert_equal 12, @generator.derive_key_from("some password", length: 12).length
  end

  private
    def assert_derive_key(secret, digest_class: OpenSSL::Digest::SHA256, length: 20)
      expected_derived_key = ActiveSupport::KeyGenerator.new(secret, hash_digest_class: digest_class)
                                                        .generate_key(ActiveRecord::Encryption.config.key_derivation_salt, length)
      assert_equal length, expected_derived_key.length
      ActiveRecord::Encryption.config.hash_digest_class = digest_class
      assert_equal expected_derived_key, ActiveRecord::Encryption::KeyGenerator.new(hash_digest_class: digest_class).derive_key_from(secret, length: length)
    end
end
