# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"
require "models/author_encrypted"

class ActiveRecord::Encryption::UniquenessValidationsTest < ActiveRecord::EncryptionTestCase
  test "uniqueness validations work" do
    EncryptedBookWithDowncaseName.create!(name: "dune")
    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithDowncaseName.create!(name: "dune")
    end
  end

  test "uniqueness validations work when mixing encrypted an unencrypted data" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    UnencryptedBook.create! name: "dune"
    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithDowncaseName.create!(name: "DUNE")
    end
  end

  test "uniqueness validations do not work when mixing encrypted an unencrypted data and unencrypted data is opted out per-attribute" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    UnencryptedBook.create! name: "dune"
    assert_nothing_raised do
      EncryptedBookWithUnencryptedDataOptedOut.create!(name: "dune")
    end
  end

  test "uniqueness validations work when mixing encrypted an unencrypted data and unencrypted data is opted in per-attribute" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    UnencryptedBook.create! name: "dune"
    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithUnencryptedDataOptedIn.create!(name: "dune")
    end
  end

  test "uniqueness validations work when using old encryption schemes" do
    ActiveRecord::Encryption.config.previous = [ { downcase: true, deterministic: true } ]

    OldEncryptionBook = Class.new(UnencryptedBook) do
      self.table_name = "encrypted_books"

      validates :name, uniqueness: true
      encrypts :name, deterministic: true, downcase: false
    end

    OldEncryptionBook.create! name: "dune"

    assert_raises ActiveRecord::RecordInvalid do
      OldEncryptionBook.create! name: "DUNE"
    end
  end

  test "uniqueness validation does not revalidate the attribute with current encryption type" do
    EncryptedBookWithUniquenessValidation.create!(name: "dune")
    record = EncryptedBookWithUniquenessValidation.create(name: "dune")

    assert_equal 1, record.errors.count
  end
end
