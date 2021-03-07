require "cases/encryption/helper"
require "models/book"

class ActiveRecord::Encryption::ExtendedDeterministicQueriesTest < ActiveRecord::TestCase
  test "Finds records when data is unencrypted" do
    ActiveRecord::Encryption.without_encryption { Book.create! name: "Dune" }
    assert EncryptedBook.find_by(name: "Dune") # core
    assert EncryptedBook.where("id > 0").find_by(name: "Dune") # relation
  end

  test "Finds records when data is encrypted" do
    Book.create! name: "Dune"
    assert EncryptedBook.find_by(name: "Dune") # core
    assert EncryptedBook.where("id > 0").find_by(name: "Dune") # relation
  end

  test "Works well with downcased attributes" do
    ActiveRecord::Encryption.without_encryption { EncryptedBookWithDowncaseName.create! name: "Dune" }
    assert EncryptedBookWithDowncaseName.find_by(name: "DUNE")
  end

  test "find_or_create works" do
    EncryptedBook.find_or_create_by!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")

    EncryptedBook.find_or_create_by!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")
  end
end
