# frozen_string_literal: true

require "cases/encryption/helper"
require "models/author_encrypted"
require "models/book_encrypted"
require "models/post_encrypted"

class ActiveRecord::Encryption::EncryptableRecordApiTest < ActiveRecord::TestCase
  fixtures :posts

  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
  end

  test "encrypt encrypts all the encryptable attributes" do
    title = "The Starfleet is here!"
    body = "<p>the Starfleet is here, we are safe now!</p>"

    post = ActiveRecord::Encryption.without_encryption do
      EncryptedPost.create! title: title, body: body
    end

    post.encrypt

    assert_encrypted_attribute(post, :title, title)
    assert_encrypted_attribute(post, :body, body)
  end

  test "encrypt won't fail for classes without attributes to encrypt" do
    posts(:welcome).encrypt
  end

  test "decrypt decrypts encrypted attributes" do
    title = "the Starfleet is here!"
    body = "<p>the Starfleet is here, we are safe now!</p>"
    post = EncryptedPost.create! title: title, body: body
    assert_encrypted_attribute(post, :title, title)
    assert_encrypted_attribute(post, :body, body)

    post.decrypt

    assert_not_encrypted_attribute post.reload, :title, title
    assert_not_encrypted_attribute post, :body, body
  end

  test "decrypt can be invoked multiple times" do
    post = EncryptedPost.create! title: "the Starfleet is here", body: "<p>the Starfleet is here, we are safe now!</p>"

    3.times { post.decrypt }

    assert_not_encrypted_attribute post.reload, :title, "the Starfleet is here"
    assert_not_encrypted_attribute post, :body, "<p>the Starfleet is here, we are safe now!</p>"
  end

  test "encrypt can be invoked multiple times" do
    post = EncryptedPost.create! title: "the Starfleet is here", body: "<p>the Starfleet is here, we are safe now!</p>"

    3.times { post.encrypt }

    assert_encrypted_attribute post.reload, :title, "the Starfleet is here"
    assert_encrypted_attribute post, :body, "<p>the Starfleet is here, we are safe now!</p>"
  end

  test "encrypted_attribute? returns false for regular attributes" do
    book = EncryptedBook.new(created_at: 1.day.ago)
    assert_not book.encrypted_attribute?(:created_at)
  end

  test "encrypted_attribute? returns true for encrypted attributes which content is encrypted" do
    book = EncryptedBook.create!(name: "Dune")
    assert book.encrypted_attribute?(:name)
  end

  test "encrypted_attribute? returns false for encrypted attributes which content is not encrypted" do
    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: "Dune") }
    assert_not book.encrypted_attribute?(:title)
  end

  test "ciphertext_for returns the chiphertext for a given attributes" do
    book = EncryptedBook.create!(name: "Dune")

    assert_equal book.ciphertext_for(:name), book.ciphertext_for(:name)
    assert_not_equal book.name, book.ciphertext_for(:name)
  end

  test "encrypt won't change the encoding of strings even when compression is used" do
    title = "The Starfleet is here  #{'OMG👌' * 50}!"
    encoding = title.encoding
    post = ActiveRecord::Encryption.without_encryption { EncryptedPost.create!(title: title, body: "some body") }
    post.encrypt
    assert_equal encoding, post.reload.title.encoding
  end

  test "encrypt will preserve case when :ignore_case option is used" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    book = create_unencrypted_book_ignoring_case name: "Dune"

    ActiveRecord::Encryption.without_encryption { assert_equal "Dune", book.reload.name }
    assert_equal "Dune", book.name

    book.encrypt

    assert_equal "Dune", book.name
  end

  test "encrypt attributes encrypted with a previous encryption scheme" do
    author = EncryptedAuthor.create!(name: "david")
    old_type = EncryptedAuthor.type_for_attribute(:name).previous_types.first
    value_encrypted_with_old_type = old_type.serialize("dhh")
    ActiveRecord::Encryption.without_encryption do
      author.update!(name: value_encrypted_with_old_type)
    end

    author.reload.encrypt
    assert_equal "dhh", author.reload.name
  end
end
