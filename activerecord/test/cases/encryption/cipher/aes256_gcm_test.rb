# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::Aes256GcmTest < ActiveRecord::EncryptionTestCase
  setup do
    @key = ActiveRecord::Encryption.key_generator.generate_random_key length: ActiveRecord::Encryption::Cipher::Aes256Gcm.key_length
    @cipher = ActiveRecord::Encryption::Cipher::Aes256Gcm.new(@key)
  end

  test "encrypts strings" do
    assert_cipher_encrypts(@cipher, "Some clear text")
  end

  test "works with empty strings" do
    assert_cipher_encrypts(@cipher, "")
  end

  test "uses non-deterministic encryption by default" do
    assert_not_equal @cipher.encrypt("Some text").payload, @cipher.encrypt("Some text").payload
  end

  test "in deterministic mode, it generates the same ciphertext for the same inputs" do
    cipher = ActiveRecord::Encryption::Cipher::Aes256Gcm.new(@key, deterministic: true)

    assert_cipher_encrypts(cipher, "Some clear text")

    assert_equal cipher.encrypt("Some text").payload, cipher.encrypt("Some text").payload
    assert_not_equal cipher.encrypt("Some text").payload, cipher.encrypt("Some other text").payload
  end

  test "it generates different ivs for different ciphertexts" do
    cipher = ActiveRecord::Encryption::Cipher::Aes256Gcm.new(@key, deterministic: true)

    assert_equal cipher.encrypt("Some text").headers.iv, cipher.encrypt("Some text").headers.iv
    assert_not_equal cipher.encrypt("Some text").headers.iv, cipher.encrypt("Some other text").headers.iv
  end

  test "inspect_does not show secrets" do
    cipher = ActiveRecord::Encryption::Cipher::Aes256Gcm.new(@key)
    assert_match(/\A#<ActiveRecord::Encryption::Cipher::Aes256Gcm:0x[0-9a-f]+>\z/, cipher.inspect)
  end

  private
    def assert_cipher_encrypts(cipher, content_to_encrypt)
      encrypted_content = cipher.encrypt(content_to_encrypt)
      assert_not_equal content_to_encrypt, encrypted_content
      assert_equal content_to_encrypt, cipher.decrypt(encrypted_content)
    end
end
