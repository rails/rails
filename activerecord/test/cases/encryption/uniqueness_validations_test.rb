# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"
require "models/author_encrypted"

class ActiveRecord::Encryption::UniquenessValidationsTest < ActiveRecord::EncryptionTestCase
  test "uniqueness validations work" do
    EncryptedBook.create!(name: "dune")
    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBook.create!(name: "dune")
    end
  end

  test "uniqueness validations work when using downcase" do
    EncryptedBookWithDowncaseName.create!(name: "dune")
    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithDowncaseName.create!(name: "dune")
    end
  end

  test "uniqueness validations work when using upcase" do
    EncryptedBookWithUpcaseName.create!(name: "dune")
    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithUpcaseName.create!(name: "dune")
    end
  end

  test "uniqueness validations work when mixing encrypted an unencrypted data" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    ActiveRecord::Encryption.without_encryption { EncryptedBook.create! name: "dune" }

    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBook.create!(name: "dune")
    end
  end

  test "uniqueness validations work when mixing encrypted an unencrypted data when using downcase" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    ActiveRecord::Encryption.without_encryption { EncryptedBookWithDowncaseName.create! name: "dune" }

    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithDowncaseName.create!(name: "dune")
    end
  end

  test "uniqueness validations work when mixing encrypted an unencrypted data when using upcase" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    ActiveRecord::Encryption.without_encryption { EncryptedBookWithUpcaseName.create! name: "dune" }

    assert_raises ActiveRecord::RecordInvalid do
      EncryptedBookWithUpcaseName.create!(name: "dune")
    end
  end

  test "uniqueness validations work when using old encryption schemes" do
    ActiveRecord::Encryption.config.previous = [ { downcase: true } ]

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
end
