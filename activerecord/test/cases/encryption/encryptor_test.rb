# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::EncryptorTest < ActiveRecord::EncryptionTestCase
  setup do
    @secret_key = "This is my secret 256 bits key!!"
    @encryptor = ActiveRecord::Encryption::Encryptor.new
  end

  test "encrypt and decrypt a string" do
    assert_encrypt_text("my secret text")
  end

  test "trying to decrypt something else than a string will raise a Decryption error" do
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      @encryptor.decrypt(:it_can_only_decrypt_strings)
    end
  end

  test "decrypt an invalid string will raise a Decryption error" do
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      @encryptor.decrypt("some test that does not make sense")
    end
  end

  test "decrypt an encrypted text with an invalid key will raise a Decryption error" do
    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      encrypted_text = @encryptor.encrypt("Some text to encrypt")
      @encryptor.decrypt(encrypted_text, key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("some invalid key"))
    end
  end

  test "if an encryption error happens when encrypting an encrypted text it should raise" do
    assert_raises(ActiveRecord::Encryption::Errors::Encryption) do
      key_provider_that_raises_an_encryption_error = ActiveRecord::Encryption::DerivedSecretKeyProvider.new("some key")
      key_provider_that_raises_an_encryption_error.stub :encryption_key, -> { raise ActiveRecord::Encryption::Errors::Encryption } do
        @encryptor.encrypt("Some text to encrypt", key_provider: key_provider_that_raises_an_encryption_error)
      end
    end
  end

  test "content is compressed" do
    content = SecureRandom.hex(5.kilobytes)
    cipher_text = @encryptor.encrypt(content)

    assert_encrypt_text content
    assert cipher_text.bytesize < content.bytesize
  end

  test "content is not compressed, when disabled" do
    @encryptor = ActiveRecord::Encryption::Encryptor.new(compress: false)
    content = SecureRandom.hex(5.kilobytes)
    cipher_text = @encryptor.encrypt(content)

    assert_encrypt_text content
    assert cipher_text.bytesize > content.bytesize
  end

  test "trying to encrypt custom classes raises a ForbiddenClass exception" do
    assert_raises ActiveRecord::Encryption::Errors::ForbiddenClass do
      @encryptor.encrypt(Struct.new(:name).new("Jorge"))
    end
  end

  test "store custom metadata with the encrypted data, accessible by the key provider" do
    key = ActiveRecord::Encryption::Key.new(@secret_key)
    key.public_tags[:key] = "my tag"
    key_provider = ActiveRecord::Encryption::KeyProvider.new(key)
    encryptor = ActiveRecord::Encryption::Encryptor.new

    key_provider.stub :decryption_keys, ->(message) { [key] } do
      decrypted_text = encryptor.decrypt encryptor.encrypt("some text", key_provider: key_provider), key_provider: key_provider
      assert decrypted_text
    end
  end

  test "encrypted? returns whether the passed text is encrypted" do
    assert @encryptor.encrypted?(@encryptor.encrypt("clean text"))
    assert_not @encryptor.encrypted?("clean text")
  end

  test "decrypt respects encoding even when compression is used" do
    text = "The Starfleet is here #{'OMG! ' * 50}!".dup.force_encoding(Encoding::ISO_8859_1)
    encrypted_text = @encryptor.encrypt(text)
    decrypted_text = @encryptor.decrypt(encrypted_text)

    assert_equal Encoding::ISO_8859_1, decrypted_text.encoding
  end

  test "accept a custom compressor" do
    compressor = Module.new do
      def self.deflate(data)
        "compressed #{data}"
      end

      def self.inflate(data)
        data.sub(/\Acompressed /, "")
      end
    end
    @encryptor = ActiveRecord::Encryption::Encryptor.new(compressor: compressor)
    content = SecureRandom.hex(5.kilobytes)

    assert_encrypt_text content
  end

  private
    def assert_encrypt_text(clean_text)
      encrypted_text = @encryptor.encrypt(clean_text)
      assert_not_equal encrypted_text, clean_text
      assert_equal clean_text, @encryptor.decrypt(encrypted_text)
    end
end
