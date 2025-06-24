# frozen_string_literal: true

require "cases/encryption/helper"
require "models/author_encrypted"

class ActiveRecord::Encryption::EncryptionSchemesTest < ActiveRecord::EncryptionTestCase
  test "can decrypt encrypted_value encrypted with a different encryption scheme" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    author = create_author_with_name_encrypted_with_previous_scheme
    assert_equal "dhh", author.reload.name
    assert author.encrypted_attribute? :name
  end

  test "when defining previous encryption schemes, you still get Decryption errors when using invalid clear values" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    author = ActiveRecord::Encryption.without_encryption { EncryptedAuthor.create!(name: "unencrypted author") }

    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      author.reload.name
    end
  end

  test "use a custom encryptor" do
    author = EncryptedAuthor1.create name: "1"
    assert_equal "1", author.name
    assert author.encrypted_attribute? :name
  end

  test "support previous contexts" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    author = EncryptedAuthor2.create name: "2"
    assert_equal "2", author.name
    assert_equal author, EncryptedAuthor2.find_by_name("2")
    assert author.encrypted_attribute? :name

    Author.find(author.id).update! name: "1"
    assert_equal "1", author.reload.name
    assert_equal author, EncryptedAuthor2.find_by_name("1")
    assert_not author.encrypted_attribute? :name
  end

  test "use global previous schemes to decrypt data encrypted with previous schemes" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    encrypted_author_class = declare_class_with_global_previous_encryption_schemes({ encryptor: TestEncryptor.new("0" => "1") }, { encryptor: TestEncryptor.new("1" => "2") })

    assert_equal 2, encrypted_author_class.type_for_attribute(:name).previous_types.count
    previous_type_1, previous_type_2 = encrypted_author_class.type_for_attribute(:name).previous_types

    author = ActiveRecord::Encryption.without_encryption do
      encrypted_author_class.create name: previous_type_1.serialize("1")
    end
    assert_equal "0", author.reload.name

    author = ActiveRecord::Encryption.without_encryption do
      encrypted_author_class.create name: previous_type_2.serialize("2")
    end
    assert_equal "1", author.reload.name
  end

  test "use global previous schemes to decrypt data encrypted with previous schemes with unencrypted data" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    encrypted_author_class = declare_class_with_global_previous_encryption_schemes({ encryptor: TestEncryptor.new("0" => "1") }, { encryptor: TestEncryptor.new("1" => "2") })

    assert_equal 3, encrypted_author_class.type_for_attribute(:name).previous_types.count
    previous_type_1, previous_type_2 = encrypted_author_class.type_for_attribute(:name).previous_types

    author = ActiveRecord::Encryption.without_encryption do
      encrypted_author_class.create name: previous_type_1.serialize("1")
    end
    assert_equal "0", author.reload.name

    author = ActiveRecord::Encryption.without_encryption do
      encrypted_author_class.create name: previous_type_2.serialize("2")
    end
    assert_equal "1", author.reload.name
  end

  test "returns ciphertext all the previous schemes fail to decrypt and support for unencrypted data is on" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    encrypted_author_class = declare_class_with_global_previous_encryption_schemes({ encryptor: TestEncryptor.new("0" => "1") }, { encryptor: TestEncryptor.new("1" => "2") })

    author = ActiveRecord::Encryption.without_encryption do
      encrypted_author_class.create name: "some ciphertext"
    end

    assert_equal "some ciphertext", author.reload.name
  end

  test "raise decryption error when all the previous schemes fail to decrypt" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    encrypted_author_class = declare_class_with_global_previous_encryption_schemes({ encryptor: TestEncryptor.new("0" => "1") }, { encryptor: TestEncryptor.new("1" => "2") })

    author = ActiveRecord::Encryption.without_encryption do
      encrypted_author_class.create name: "some invalid ciphertext"
    end

    assert_raise ActiveRecord::Encryption::Errors::Decryption do
      author.reload.name
    end
  end

  test "deterministic encryption is fixed by default: it will always use the oldest scheme to encrypt data" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    ActiveRecord::Encryption.config.deterministic_key = "12345"
    ActiveRecord::Encryption.config.previous = [{ downcase: true, deterministic: true }, { downcase: false, deterministic: true }]

    encrypted_author_class = Class.new(Author) do
      self.table_name = "authors"

      encrypts :name, deterministic: true, downcase: false
    end

    author = encrypted_author_class.create!(name: "STEPHEN KING")
    assert_equal "stephen king", author.name
  end

  test "don't use global previous schemes with a different deterministic nature" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    ActiveRecord::Encryption.config.deterministic_key = "12345"
    ActiveRecord::Encryption.config.previous = [{ downcase: true, deterministic: false }, { downcase: false, deterministic: true }]

    encrypted_author_class = Class.new(Author) do
      self.table_name = "authors"

      encrypts :name, deterministic: true, downcase: false
    end

    author = encrypted_author_class.create!(name: "STEPHEN KING")
    assert_equal "STEPHEN KING", author.name
  end

  test "deterministic encryption will use the newest encryption scheme to encrypt data when setting it to { fixed: false }" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    ActiveRecord::Encryption.config.deterministic_key = "12345"
    ActiveRecord::Encryption.config.previous = [{ downcase: true, deterministic: true }, { downcase: false, deterministic: true }]

    encrypted_author_class = Class.new(Author) do
      self.table_name = "authors"

      encrypts :name, deterministic: { fixed: false }, downcase: false
    end

    author = encrypted_author_class.create!(name: "STEPHEN KING")
    assert_equal "STEPHEN KING", author.name
  end

  test "use global previous schemes when performing queries" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    ActiveRecord::Encryption.config.deterministic_key = "12345"
    ActiveRecord::Encryption.config.previous = [{ downcase: true, deterministic: true }, { downcase: false, deterministic: true }]

    encrypted_author_class = Class.new(Author) do
      self.table_name = "authors"

      encrypts :name, deterministic: true, downcase: false
    end

    author = encrypted_author_class.create!(name: "STEPHEN KING")
    assert_equal author, encrypted_author_class.find_by_name("STEPHEN KING")
    assert_equal author, encrypted_author_class.find_by_name("stephen king")
  end

  test "don't use global previous schemes with a different deterministic nature when performing queries" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    ActiveRecord::Encryption.config.deterministic_key = "12345"
    ActiveRecord::Encryption.config.previous = [{ downcase: true, deterministic: false }, { downcase: false, deterministic: true }]

    encrypted_author_class = Class.new(Author) do
      self.table_name = "authors"

      encrypts :name, deterministic: true, downcase: false
    end

    author = encrypted_author_class.create!(name: "STEPHEN KING")
    assert_equal author, encrypted_author_class.find_by_name("STEPHEN KING")
    assert_nil encrypted_author_class.find_by_name("stephen king")
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
        decrypt(text)
      rescue ActiveRecord::Encryption::Errors::Decryption
        false
      end

      def binary?
        false
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

    def declare_class_with_global_previous_encryption_schemes(*previous_schemes)
      ActiveRecord::Encryption.config.previous = previous_schemes

      # We want to evaluate .encrypts *after* tweaking the config property
      Class.new(Author) do
        self.table_name = "authors"

        encrypts :name
      end.tap { |klass| klass.type_for_attribute(:name) }
    end
end
