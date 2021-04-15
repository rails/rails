# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::CipherTest < ActiveRecord::EncryptionTestCase
  setup do
    @cipher = ActiveRecord::Encryption::Cipher.new
    @key = ActiveRecord::Encryption.key_generator.generate_random_key
  end

  test "encrypts returns a encrypted test that can be decrypted with the same key" do
    encrypted_text = @cipher.encrypt("clean text", key: @key)
    assert_equal "clean text", @cipher.decrypt(encrypted_text, key: @key)
  end

  test "by default, encrypts uses random initialization vectors for each encryption operation" do
    assert_not_equal @cipher.encrypt("clean text", key: @key), @cipher.encrypt("clean text", key: @key)
  end

  test "deterministic encryption with :deterministic param" do
    assert_equal @cipher.encrypt("clean text", key: @key, deterministic: true).payload, @cipher.encrypt("clean text", key: @key, deterministic: true).payload
  end

  test "raises an ArgumentError when provided a key with the wrong length" do
    assert_raises ArgumentError do
      @cipher.encrypt("clean text", key: "invalid key")
    end
  end

  test "iv_length returns the iv length of the cipher" do
    assert_equal OpenSSL::Cipher.new("aes-256-gcm").iv_len, @cipher.iv_length
  end

  test "generates different ciphertexts on different invocations with the same key (not deterministic)" do
    key = SecureRandom.bytes(32)
    assert_not_equal @cipher.encrypt("clean text", key: key), @cipher.encrypt("clean text", key: key)
  end

  test "decrypt can work with multiple keys" do
    encrypted_text = @cipher.encrypt("clean text", key: @key)

    assert_equal "clean text", @cipher.decrypt(encrypted_text, key: [ "some wrong key", @key ])
    assert_equal "clean text", @cipher.decrypt(encrypted_text, key: [ "some wrong key", @key, "some other wrong key" ])
    assert_equal "clean text", @cipher.decrypt(encrypted_text, key: [ @key, "some wrong key", "some other wrong key" ])
  end

  test "decrypt will raise an ActiveRecord::Encryption::Errors::Decryption error when none of the keys works" do
    encrypted_text = @cipher.encrypt("clean text", key: @key)

    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      @cipher.decrypt(encrypted_text, key: [ "some wrong key", "other wrong key" ])
    end
  end

  test "keep encoding from the source string" do
    encrypted_text = @cipher.encrypt("some string".dup.force_encoding(Encoding::ISO_8859_1), key: @key)
    decrypted_text = @cipher.decrypt(encrypted_text, key: @key)
    assert_equal Encoding::ISO_8859_1, decrypted_text.encoding
  end

  test "can encode unicode strings with emojis" do
    encrypted_text = @cipher.encrypt("Getting around with the ⚡️Go Menu", key: @key)
    assert_equal "Getting around with the ⚡️Go Menu", @cipher.decrypt(encrypted_text, key: @key)
  end
end
