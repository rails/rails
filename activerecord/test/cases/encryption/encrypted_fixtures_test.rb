# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"

class ActiveRecord::Encryption::EncryptableFixtureTest < ActiveRecord::EncryptionTestCase
  self.use_transactional_tests = false

  fixtures :encrypted_books, :encrypted_book_that_ignores_cases, :encrypted_book_with_json

  test "fixtures get encrypted automatically" do
    assert encrypted_books(:awdr).encrypted_attribute?(:name)
  end

  test "preserved columns due to ignore_case: true gets encrypted automatically" do
    book = encrypted_book_that_ignores_cases(:rfr)
    assert_equal "Ruby for Rails", book.name
    assert_encrypted_attribute book, :name, "Ruby for Rails"

    assert EncryptedBookThatIgnoresCase.find_by_name("Ruby for Rails")
  end

  test "fixtures for json columns get encrypted automatically" do
    skip "JSON columns are not supported" unless ActiveRecord::Base.lease_connection.supports_json?

    book = encrypted_book_with_json(:pickaxe)
    assert book.encrypted_attribute?(:metadata)
    assert_encrypted_attribute book, :metadata, { "pages" => 448, "edition" => 4 }
  end
end
