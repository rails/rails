require "cases/encryption/helper"
require "models/book"

class ActiveRecord::Encryption::EncryptableFixtureTest < ActiveRecord::TestCase
  fixtures :encrypted_books, :encrypted_book_that_ignores_cases

  test "fixtures get encrypted automatically" do
    assert encrypted_books(:awdr).encrypted_attribute?(:name)
  end

  test "preserved columns due to ignore_case: true gets encrypted automatically" do
    book = encrypted_book_that_ignores_cases(:rfr)
    assert_equal "Ruby for Rails", book.name
    assert_encrypted_attribute book, :name, "Ruby for Rails"

    assert EncryptedBookThatIgnoresCase.find_by_name("Ruby for Rails")
  end
end
