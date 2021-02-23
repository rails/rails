require "cases/encryption/helper"
require "models/author"
require "models/book"
require "models/post"
require "models/traffic_light"

class ActiveRecord::Encryption::EncryptableRecordTest < ActiveRecord::TestCase
  fixtures :books, :posts

  test "encrypts the attribute seamlessly when creating and updating records" do
    post = EncryptedPost.create!(title: "The Starfleet is here!", body: "take cover!")
    assert_encrypted_attribute(post, :title, "The Starfleet is here!")

    post.update!(title: "The Klingons are coming!")
    assert_encrypted_attribute(post, :title, "The Klingons are coming!")

    post.title = "You sure?"
    post.save!
    assert_encrypted_attribute(post, :title, "You sure?")

    post[:title] = "The Klingons are leaving!"
    post.save!
    assert_encrypted_attribute(post, :title, "The Klingons are leaving!")
  end

  test "attribute is not accessible with the wrong key" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    post = EncryptedPost.create!(title: "The Starfleet is here!", body: "take cover!")
    post.reload.tags_count # accessing regular attributes works
    assert_invalid_key_cant_read_attribute(post, :title)
  end

  test "ignores nil values" do
    assert_nil EncryptedBook.create!(name: nil).name
  end

  test "ignores empty values" do
    assert_equal "", EncryptedBook.create!(name: "").name
  end

  test "encrypts serialized attributes" do
    states = %i[ green red ]
    traffic_light = EncryptedTrafficLight.create!(state: states, long_state: states)
    assert_encrypted_attribute(traffic_light, :state, states)
  end

  test "can configure a custom key provider on a per-record-class basis through the :key_provider option" do
    post = EncryptedPost.create!(title: "The Starfleet is here!", body: "take cover!")
    assert_encrypted_attribute(post, :body, "take cover!")
  end

  test "can configure a custom key on a per-record-class basis through the :key option" do
    author = EncryptedAuthor.create!(name: "Stephen King")
    assert_encrypted_attribute(author, :name, "Stephen King")
  end

  test "encrypts multiple attributes with different options at the same time" do
    post = EncryptedPost.create!\
      title: title = "The Starfleet is here!",
      body: body = "<p>the Starfleet is here, we are safe now!</p>"

    assert_encrypted_attribute(post, :title, title)
    assert_encrypted_attribute(post, :body, body)
  end

  test "encrypted_attributes returns the list of encrypted attributes in a model (each record class holds their own list)" do
    assert_equal Set.new([:title, :body]), EncryptedPost.encrypted_attributes
    assert_not_equal EncryptedAuthor.encrypted_attributes, EncryptedPost.encrypted_attributes
  end

  test "deterministic_encrypted_attributes returns the list of deterministic encrypted attributes in a model (each record class holds their own list)" do
    assert_equal [:name], EncryptedBook.deterministic_encrypted_attributes
    assert_not_equal EncryptedPost.deterministic_encrypted_attributes, EncryptedBook.deterministic_encrypted_attributes
  end

  test "by default, encryption is not deterministic" do
    post_1 = EncryptedPost.create!(title: "the same title", body: "some body")
    post_2 = EncryptedPost.create!(title: "the same title", body: "some body")

    assert_not_equal post_1.ciphertext_for(:title), post_2.ciphertext_for(:title)
  end

  test "deterministic attributes can be searched with Active Record queries" do
    EncryptedBook.create!(name: "Dune")

    assert EncryptedBook.find_by(name: "Dune")
    assert_not EncryptedBook.find_by(name: "not Dune")

    assert_equal 1, EncryptedBook.where(name: "Dune").count
  end

  test "deterministic attributes can be created by passing deterministic: true" do
    book_1 = EncryptedBook.create!(name: "Dune")
    book_2 = EncryptedBook.create!(name: "Dune")

    assert_equal book_1.ciphertext_for(:name), book_2.ciphertext_for(:name)
  end

  test "encryption errors when saving records will raise the error and don't save anything" do
    assert_no_changes -> { BookThatWillFailToEncryptName.count } do
      assert_raises ActiveRecord::Encryption::Errors::Encryption do
        BookThatWillFailToEncryptName.create!(name: "Dune")
      end
    end
  end

  test "can work with pre-encryption nil values" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: nil) }
    assert_nil book.name
  end

  test "can work with pre-encryption empty values" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
    book = ActiveRecord::Encryption.without_encryption { EncryptedBook.create!(name: "") }
    assert_equal "", book.name
  end

  test "can't modify encrypted attributes when frozen_encryption is true" do
    post = posts(:welcome).becomes(EncryptedPost)
    post.title = "Some new title"
    assert post.valid?

    ActiveRecord::Encryption.with_encryption_context frozen_encryption: true do
      assert_not post.valid?
    end
  end

  test "can only save unencrypted attributes when frozen encryption is true" do
    book = books(:awdr).becomes(EncryptedBook)
    ActiveRecord::Encryption.with_encryption_context frozen_encryption: true do
      book.update! updated_at: Time.now
    end

    ActiveRecord::Encryption.with_encryption_context frozen_encryption: true do
      assert_raises ActiveRecord::RecordInvalid do
        book.update! name: "Some new title"
      end
    end
  end

  test "won't change the encoding of strings" do
    author_name = "Jorge"
    encoding = author_name.encoding
    author = EncryptedAuthor.create!(name: author_name)
    assert_equal encoding, author.reload.name.encoding
  end

  test "by default, it's case sensitive" do
    EncryptedBook.create!(name: "Dune")
    assert EncryptedBook.find_by(name: "Dune")
    assert_not EncryptedBook.find_by(name: "dune")
  end

  test "when using downcase: true it ignores case since everything will be downcase" do
    EncryptedBookWithDowncaseName.create!(name: "Dune")
    assert EncryptedBookWithDowncaseName.find_by(name: "Dune")
    assert EncryptedBookWithDowncaseName.find_by(name: "dune")
    assert EncryptedBookWithDowncaseName.find_by(name: "DUNE")
  end

  test "when downcase: true it creates content downcased" do
    EncryptedBookWithDowncaseName.create!(name: "Dune")
    assert EncryptedBookWithDowncaseName.find_by_name("dune")
  end

  test "when ignore_downcase: true, it ignores case in queries but keep it when reading the attribute" do
    EncryptedBookThatIgnoresCase.create!(name: "Dune")
    book = EncryptedBookThatIgnoresCase.find_by_name("dune")
    assert book
    assert "Dune", book.name
  end

  test "when ignore_downcase: true, it keeps both the attribute and the _original counterpart encrypted" do
    book = EncryptedBookThatIgnoresCase.create!(name: "Dune")
    assert_encrypted_attribute book, :name, "Dune"
    assert_encrypted_attribute book, :original_name, "Dune"
  end

  test "when ignore_downcase: true, it lets you update attributes normally" do
    book = EncryptedBookThatIgnoresCase.create!(name: "Dune")
    book.update!(name: "Dune II")
    assert_equal "Dune II", book.name
  end

  test "when ignore_downcase: true, it returns the actual value when not encrypted" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    book = create_unencrypted_book_ignoring_case name: "Dune"
    assert_equal "Dune", book.name
  end

  test "reading a not encrypted value will raise a Decryption error when :support_unencrypted_data is false" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    book = ActiveRecord::Encryption.without_encryption do
      EncryptedBookThatIgnoresCase.create!(name: "dune")
    end

    assert_raises(ActiveRecord::Encryption::Errors::Decryption) do
      book.name
    end
  end

  test "reading a not encrypted value won't raise a Decryption error when :support_unencrypted_data is true" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    author = ActiveRecord::Encryption.without_encryption do
      EncryptedAuthor.create!(name: "Stephen King")
    end

    assert_equal "Stephen King", author.name
  end

  if current_adapter?(:Mysql2Adapter)
    test "validate column sizes" do
      assert EncryptedAuthor.new(name: "jorge").valid?
      assert_not EncryptedAuthor.new(name: "a" * 256).valid?
      author = EncryptedAuthor.create(name: "a" * 256)
      assert_not author.valid?
    end
  end

  test "track previous changes properly for encrypted attributes" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    book = EncryptedBook.create!(name: "Dune")
    book.update!(created_at: 1.hour.ago)
    assert_not book.name_previously_changed?

    book.update!(name: "A new title!")
    assert book.name_previously_changed?
  end

  private
    class FailingKeyProvider
      def decryption_key(message) end

      def encryption_key
        raise ActiveRecord::Encryption::Errors::Encryption
      end
    end

    class BookThatWillFailToEncryptName < Book
      self.table_name = "books"

      encrypts :name, key_provider: FailingKeyProvider.new
    end
end
