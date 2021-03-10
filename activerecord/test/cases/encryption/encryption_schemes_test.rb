# frozen_string_literal: true

require "cases/encryption/helper"
require "models/author"

class ActiveRecord::Encryption::EncryptionSchemesTest < ActiveRecord::TestCase
  test "can decrypt encrypted_value encrypted with a different encryption scheme" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    author = create_author_with_name_encrypted_with_previous_scheme
    assert_equal "dhh", author.reload.name
  end

  test "when defining previous encryption schemes, you still get Decryption errors when using invalid clear_value" do
    author = ActiveRecord::Encryption.without_encryption { EncryptedAuthor.create!(name: "unencrypted author") }

    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      author.reload.name
    end
  end

  test "use a custom encryptor" do
    author = EncryptedAuthor1.create name: "1"
    assert_equal "1", author.name
  end

  test "support previous contexts" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    author = EncryptedAuthor2.create name: "2"
    assert_equal "2", author.name
    assert_equal author, EncryptedAuthor2.find_by_name("2")

    Author.find(author.id).update! name: "1"
    assert_equal "1", author.reload.name
    assert_equal author, EncryptedAuthor2.find_by_name("1")
  end

  private
    class TestEncryptor
      def initialize(ciphertexts_by_clear_value)
        @ciphertexts_by_clear_value = ciphertexts_by_clear_value
      end

      def encrypt(clear_text, key_provider: nil, cipher_options: {})
        @ciphertexts_by_clear_value[clear_text] || clear_text
      end

      def decrypt(encrypted_text, key_provider: nil, cipher_options: {})
        @ciphertexts_by_clear_value.each { |clear_value, encrypted_value| return clear_value if encrypted_value == encrypted_text }
        raise ActiveRecord::Encryption::Errors::Decryption, "Couldn't find a match for #{encrypted_text} (#{@ciphertexts_by_clear_value.inspect})"
      end

      def encrypted?(text)
        text == encrypted_text
      end
    end

    class EncryptedAuthor1 < Author
      self.table_name = "authors"

      encrypts :name, encryptor: TestEncryptor.new("1" => "2")
    end

    class EncryptedAuthor2 < Author
      self.table_name = "authors"

      encrypts :name, encryptor: TestEncryptor.new("2" => "3"), previous: { encryptor: TestEncryptor.new("1" => "2") }
    end

    def create_author_with_name_encrypted_with_previous_scheme
      author = EncryptedAuthor.create!(name: "david")
      old_type = EncryptedAuthor.type_for_attribute(:name).previous_types.first
      value_encrypted_with_old_type = old_type.serialize("dhh")
      ActiveRecord::Encryption.without_encryption do
        author.update!(name: value_encrypted_with_old_type)
      end
      author
    end
end
