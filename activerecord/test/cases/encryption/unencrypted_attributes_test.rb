# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

class ActiveRecord::Encryption::UnencryptedAttributesTest < ActiveRecord::EncryptionTestCase
  setup do
    @_support_unencrypted_data_was = ActiveRecord::Encryption.config.support_unencrypted_data
    @_support_unencrypted_data_default_value_was = ActiveRecord::Encryption.config.support_unencrypted_data_default_value
  end

  teardown do
    ActiveRecord::Encryption.config.support_unencrypted_data = @_support_unencrypted_data_was
    ActiveRecord::Encryption.config.support_unencrypted_data_default_value = @_support_unencrypted_data_default_value_was
  end

  test "when :support_unencrypted_data is on, it works with unencrypted attributes normally" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: "The Secrets of Starfleet") }
    assert_not_encrypted_attribute(book, :name, "The Secrets of Starfleet")

    # It will encrypt on saving
    book.update! name: "Other name"
    assert_encrypted_attribute(book.reload, :name, "Other name")
  end

  test "when :support_unencrypted_data is on, :support_unencrypted_data_default_value can take effect" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    ActiveRecord::Encryption.config.support_unencrypted_data_default_value = false

    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: "The Secrets of Starfleet") }

    # this would succeed if the default were `true`
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      book.name
    end
  end

  test "when :support_unencrypted_data is on, the model config takes precedence over the default value" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    ActiveRecord::Encryption.config.support_unencrypted_data_default_value = false

    book = ActiveRecord::Encryption.without_encryption { EncryptedBookWithUnencryptedDataOptedIn.create!(name: "The Secrets of Starfleet") }
    # this would fail if the default were being used
    assert_not_encrypted_attribute(book, :name, "The Secrets of Starfleet")

    # It will encrypt on saving
    book.update! name: "Other name"
    assert_encrypted_attribute(book.reload, :name, "Other name")
  end

  test "when :support_unencrypted_data is off, it won't work with unencrypted attributes" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: "The Secrets of Starfleet") }

    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      book.name
    end
  end

  test "when :support_unencrypted_data is off it ignores :support_unencrypted_data_default_value" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false
    ActiveRecord::Encryption.config.support_unencrypted_data_default_value = true

    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: "The Secrets of Starfleet") }

    # would succeed here if it the default was being used
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      book.name
    end
  end

  test "when :support_unencrypted_data is off it ignores the model config" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    book = ActiveRecord::Encryption.without_encryption { EncryptedBookWithUnencryptedDataOptedIn.create!(name: "The Secrets of Starfleet") }

    # would succeed here if it the model config was being used
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      book.name
    end
  end
end
