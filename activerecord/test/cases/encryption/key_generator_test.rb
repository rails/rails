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
end
