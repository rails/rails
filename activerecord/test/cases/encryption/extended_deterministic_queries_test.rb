# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"
require "active_support/core_ext/object/with"

class ActiveRecord::Encryption::ExtendedDeterministicQueriesTest < ActiveRecord::EncryptionTestCase
  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
  end

  test "Finds records when data is unencrypted" do
    UnencryptedBook.create!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune") # core
    assert EncryptedBook.where("id > 0").find_by(name: "Dune") # relation
  end

  test "Finds records when data is encrypted" do
    EncryptedBook.create!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune") # core
    assert EncryptedBook.where("id > 0").find_by(name: "Dune") # relation
  end

  test "Works well with downcased attributes" do
    EncryptedBookWithDowncaseName.create! name: "Dune"
    assert EncryptedBookWithDowncaseName.find_by(name: "DUNE")
  end

  test "Works well with string attribute names" do
    UnencryptedBook.create! "name" => "Dune"
    assert EncryptedBook.find_by("name" => "Dune")
  end

  test "find_or_create_by works" do
    EncryptedBook.find_or_create_by!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")

    EncryptedBook.find_or_create_by!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")
  end

  test "does not mutate arguments" do
    props = { name: "Dune" }

    assert_equal "Dune", EncryptedBook.find_or_initialize_by(props).name
    assert_equal "Dune", props[:name]
  end

  test "where(...).first_or_create works" do
    EncryptedBook.where(name: "Dune").first_or_create
    assert EncryptedBook.exists?(name: "Dune")
  end

  test "exists?(...) works" do
    EncryptedBook.create! name: "Dune"
    assert EncryptedBook.exists?(name: "Dune")
  end

  test "If support_unencrypted_data is opted out at the attribute level, cannot find unencrypted data" do
    UnencryptedBook.create! name: "Dune"
    assert_nil EncryptedBookWithUnencryptedDataOptedOut.find_by(name: "Dune") # core
    assert_nil EncryptedBookWithUnencryptedDataOptedOut.where("id > 0").find_by(name: "Dune") # relation
  end

  test "If support_unencrypted_data is opted out at the attribute level, can find encrypted data" do
    EncryptedBook.create! name: "Dune"
    assert EncryptedBookWithUnencryptedDataOptedOut.find_by(name: "Dune") # core
    assert EncryptedBookWithUnencryptedDataOptedOut.where("id > 0").find_by(name: "Dune") # relation
  end

  test "If support_unencrypted_data is opted in at the attribute level, can find unencrypted data" do
    UnencryptedBook.create! name: "Dune"
    assert EncryptedBookWithUnencryptedDataOptedIn.find_by(name: "Dune") # core
    assert EncryptedBookWithUnencryptedDataOptedIn.where("id > 0").find_by(name: "Dune") # relation
  end

  test "If support_unencrypted_data is opted in at the attribute level, can find encrypted data" do
    EncryptedBook.create! name: "Dune"
    assert EncryptedBookWithUnencryptedDataOptedIn.find_by(name: "Dune") # core
    assert EncryptedBookWithUnencryptedDataOptedIn.where("id > 0").find_by(name: "Dune") # relation
  end

  test "if support_unencrypted_data config is disabled, but support_unencrypted_data is opted in at an attribute level, can find unencrypted data" do
    ActiveRecord::Encryption.config.with(support_unencrypted_data: false) do
      UnencryptedBook.create! name: "Dune"
      assert EncryptedBookWithUnencryptedDataOptedIn.find_by(name: "Dune") # core
      assert EncryptedBookWithUnencryptedDataOptedIn.where("id > 0").find_by(name: "Dune") # relation
    end
  end

  test "if support_unencrypted_data config is disabled, but support_unencrypted_data is opted in at an attribute level, can find encrypted data" do
    ActiveRecord::Encryption.config.with(support_unencrypted_data: false) do
      EncryptedBook.create! name: "Dune"
      assert EncryptedBookWithUnencryptedDataOptedIn.find_by(name: "Dune") # core
      assert EncryptedBookWithUnencryptedDataOptedIn.where("id > 0").find_by(name: "Dune") # relation
    end
  end

  test "Finds records when the deterministic attribute is on a joined table, keyed by table name" do
    unencrypted_author, encrypted_author = authors_with_books_named("Dune")

    assert_equal [ unencrypted_author, encrypted_author ],
      EncryptedBookAuthor.joins(:encrypted_books).where(encrypted_books: { name: "Dune" }).order(:id).to_a
  end

  test "Finds records when the deterministic attribute is on a joined table, keyed by association name" do
    unencrypted_author, encrypted_author = authors_with_books_named("Dune")

    assert_equal [ unencrypted_author, encrypted_author ],
      EncryptedBookAuthor.joins(:kept_books).where(kept_books: { name: "Dune" }).order(:id).to_a
  end

  test "Finds records when the deterministic attribute is on a table joined through an association" do
    unencrypted_author, encrypted_author = authors_with_books_named("Dune")
    unencrypted = EncryptedBookCategorization.create! author_id: unencrypted_author.id
    encrypted = EncryptedBookCategorization.create! author_id: encrypted_author.id

    assert_equal [ unencrypted, encrypted ],
      EncryptedBookCategorization.joins(author: :encrypted_books).where(encrypted_books: { name: "Dune" }).order(:id).to_a
  end

  test "Finds records with the nested hash form when the deterministic attribute is on the model's own table" do
    unencrypted_author, encrypted_author = authors_with_books_named("Dune")

    assert_equal [ unencrypted_author.id, encrypted_author.id ],
      EncryptedBook.where(encrypted_books: { name: "Dune" }).order(:author_id).pluck(:author_id)
  end

  test "find_by works with the nested hash form" do
    unencrypted_author, _ = authors_with_books_named("Dune")

    assert_equal unencrypted_author.id, EncryptedBook.order(:author_id).find_by(encrypted_books: { name: "Dune" }).author_id
  end

  test "Does not mutate nested arguments" do
    props = { encrypted_books: { name: "Dune" } }

    EncryptedBookAuthor.joins(:encrypted_books).where(props).to_a
    assert_equal({ encrypted_books: { name: "Dune" } }, props)
  end

  test "Leaves nested arguments alone when the attribute is not deterministically encrypted" do
    author = EncryptedBookAuthor.create! name: "Frank Herbert"
    EncryptedBook.create! name: "Dune", format: "papyrus", author_id: author.id

    assert_equal [ author ], EncryptedBookAuthor.joins(:encrypted_books).where(encrypted_books: { format: "papyrus" }).to_a
  end

  private
    def authors_with_books_named(name)
      unencrypted_author = EncryptedBookAuthor.create! name: "Unencrypted"
      encrypted_author = EncryptedBookAuthor.create! name: "Encrypted"

      UnencryptedBook.create! name: name, author_id: unencrypted_author.id
      EncryptedBook.create! name: name, author_id: encrypted_author.id

      [ unencrypted_author, encrypted_author ]
    end
end
