# frozen_string_literal: true

require "cases/encryption/helper"
require "models/author_encrypted"
require "models/book_encrypted"
require "models/post_encrypted"
require "models/traffic_light_encrypted"

class ActiveRecord::Encryption::EncryptableRecordTest < ActiveRecord::EncryptionTestCase
  fixtures :encrypted_books, :posts

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
    assert_invalid_key_cant_read_attribute(post, :body)
  end

  test "swapping key_providers via with_encryption_context" do
    key_provider1 = ActiveRecord::Encryption::DerivedSecretKeyProvider.new(SecureRandom.base64(32))
    key_provider2 = ActiveRecord::Encryption::DerivedSecretKeyProvider.new(SecureRandom.base64(32))

    post1 = post2 = nil

    ActiveRecord::Encryption.with_encryption_context key_provider: key_provider1 do
      post1 = EncryptedPost.create!(title: "post1!", body: "first post!")
    end

    ActiveRecord::Encryption.with_encryption_context key_provider: key_provider2 do
      post2 = EncryptedPost.create!(title: "post2!", body: "second post!")
    end

    post1.reload
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      post1.title
    end

    post2.reload
    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      post2.title
    end

    ActiveRecord::Encryption.with_encryption_context key_provider: key_provider1 do
      post1.reload
      assert_equal "post1!", post1.title

      post2.reload
      assert_raises ActiveRecord::Encryption::Errors::Decryption do
        post2.title
      end
    end

    ActiveRecord::Encryption.with_encryption_context key_provider: key_provider2 do
      post2.reload
      assert_equal "post2!", post2.title

      post1.reload
      assert_raises ActiveRecord::Encryption::Errors::Decryption do
        post1.title
      end
    end
  end

  test "ignores nil values" do
    assert_nil EncryptedBook.create!(name: nil).name
  end

  test "ignores empty values" do
    assert_equal "", EncryptedBook.create!(name: "").name
  end

  test "encrypts serialized attributes" do
    states = ["green", "red"]
    traffic_light = EncryptedTrafficLight.create!(state: states, long_state: states)
    assert_encrypted_attribute(traffic_light, :state, states)
  end

  test "encrypts serialized attributes where encrypts is declared first" do
    states = ["green", "red"]
    traffic_light = EncryptedFirstTrafficLight.create!(state: states, long_state: states)
    assert_encrypted_attribute(traffic_light, :state, states)
  end

  test "encrypts store attributes with accessors" do
    traffic_light = EncryptedTrafficLightWithStoreState.create!(color: "red", long_state: ["green", "red"])
    assert_equal "red", traffic_light.color
    assert_encrypted_attribute(traffic_light, :state, { "color" => "red" })
  end

  test "can configure a custom key provider on a per-record-class basis through the :key_provider option" do
    post = EncryptedPost.create!(title: "The Starfleet is here!", body: "take cover!")
    assert_encrypted_attribute(post, :body, "take cover!")
  end

  test "can configure a custom key on a per-record-class basis through the :key option" do
    author = EncryptedAuthorWithKey.create!(name: "Stephen King")
    assert_encrypted_attribute(author, :name, "Stephen King")
  end

  test "encrypts multiple attributes with different options at the same time" do
    post = EncryptedPost.create! \
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

  test "deterministic ciphertexts remain constant" do
    # We need to make sure these don't change or existing apps will stop working
    ciphertext = "{\"p\":\"DIohhw==\",\"h\":{\"iv\":\"wEPaDcJP3VNIxaiz\",\"at\":\"X7+2xvvcu1k1if6Dy28Esw==\"}}"
    book = UnencryptedBook.create name: ciphertext

    book = EncryptedBook.find(book.id)
    assert_equal "Dune", book.name
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
    assert_predicate post, :valid?

    ActiveRecord::Encryption.with_encryption_context frozen_encryption: true do
      assert_not post.valid?
    end
  end

  test "can only save unencrypted attributes when frozen encryption is true" do
    book = encrypted_books(:awdr)

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

  test "when ignore_case: true, it ignores case in queries but keep it when reading the attribute" do
    EncryptedBookThatIgnoresCase.create!(name: "Dune")
    book = EncryptedBookThatIgnoresCase.find_by_name("dune")
    assert book
    assert_equal "Dune", book.name
  end

  test "when ignore_case: true, it keeps both the attribute and the _original counterpart encrypted" do
    book = EncryptedBookThatIgnoresCase.create!(name: "Dune")
    assert_encrypted_attribute book, :name, "Dune"
    assert_encrypted_attribute book, :original_name, "Dune"
  end

  test "when ignore_case: true, it lets you update attributes normally" do
    book = EncryptedBookThatIgnoresCase.create!(name: "Dune")
    book.update!(name: "Dune II")
    assert_equal "Dune II", book.name
  end

  test "when ignore_case: true, it returns the actual value when not encrypted" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    book = create_unencrypted_book_ignoring_case name: "Dune"
    assert_equal "Dune", book.name
  end

  test "when ignore_case: true, users can override accessors and call super" do
    overriding_class = Class.new(EncryptedBookThatIgnoresCase) do
      self.table_name = "books"

      def name
        "#{super}-overridden"
      end
    end

    overriding_class.create!(name: "Dune")
    book = overriding_class.find_by_name("dune")
    assert book
    assert_equal "Dune-overridden", book.reload.name
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

  # Only run for adapters that add a default string limit when not provided (MySQL, 255)
  if author_name_limit = EncryptedAuthor.columns_hash["name"].limit
    # No column limits in SQLite
    test "validate column sizes" do
      assert_predicate EncryptedAuthor.new(name: "jorge"), :valid?
      assert_not EncryptedAuthor.new(name: "a" * (author_name_limit + 1)).valid?
      author = EncryptedAuthor.create(name: "a" * (author_name_limit + 1))
      assert_not author.valid?
    end
  end

  test "track previous changes properly for encrypted attributes" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    book = EncryptedBook.create!(name: "Dune")
    book.update!(created_at: 1.hour.ago)
    assert_not book.name_previously_changed?

    book.update!(name: "A new title!")
    assert_predicate book, :name_previously_changed?
  end

  test "forces UTF-8 encoding for deterministic attributes by default" do
    book = EncryptedBook.create!(name: "Dune".encode("ASCII-8BIT"))
    assert_equal Encoding::UTF_8, book.reload.name.encoding
  end

  test "forces encoding for deterministic attributes based on the configured option" do
    ActiveRecord::Encryption.config.forced_encoding_for_deterministic_encryption = Encoding::US_ASCII

    book = EncryptedBook.create!(name: "Dune".encode("ASCII-8BIT"))
    assert_equal Encoding::US_ASCII, book.reload.name.encoding
  end

  test "forced encoding for deterministic attributes will replace invalid characters" do
    book = EncryptedBook.create!(name: "Hello \x93\xfa".b)
    assert_equal "Hello ��", book.reload.name
  end

  test "forced encoding for deterministic attributes can be disabled" do
    ActiveRecord::Encryption.config.forced_encoding_for_deterministic_encryption = nil

    book = EncryptedBook.create!(name: "Dune".encode("US-ASCII"))
    assert_equal Encoding::US_ASCII, book.reload.name.encoding
  end

  test "support encrypted attributes defined on columns with default values" do
    book = EncryptedBook.create!
    assert_encrypted_attribute(book, :name, "<untitled>")
  end

  test "loading records with encrypted attributes defined on columns with default values" do
    skip unless supports_insert_on_duplicate_update?

    EncryptedBook.insert({ format: "ebook" })
    book = EncryptedBook.last
    assert_equal "<untitled>", book.name
  end

  test "can dump and load records that use encryption" do
    book = EncryptedBook.create!
    assert_equal book, Marshal.load(Marshal.dump(book))
  end

  test "supports decrypting data encrypted non deterministically with SHA1 when digest class is SHA256" do
    ActiveRecord::Encryption.configure \
      primary_key: "the primary key",
      deterministic_key: "the deterministic key",
      key_derivation_salt: "the salt",
      support_sha1_for_non_deterministic_encryption: true

    key_provider_sha1 = build_derived_key_provider_with OpenSSL::Digest::SHA1
    key_provider_sha256 = build_derived_key_provider_with OpenSSL::Digest::SHA256

    encrypted_post_class_sha_1 = Class.new(Post) do
      self.table_name = "posts"
      encrypts :title, key_provider: key_provider_sha1
    end
    encrypted_post_class_sha_1.create! title: "Post 1", body: "The post body", type: nil

    encrypted_post_class_sha_256 = Class.new(Post) do
      self.table_name = "posts"
      encrypts :title, key_provider: key_provider_sha256
    end

    assert_equal "Post 1", encrypted_post_class_sha_256.last.title
  end

  test "encryption schemes are resolved when used, not when declared" do
    OtherEncryptedPost = Class.new(Post) do
      self.table_name = "posts"
      encrypts :title
    end

    ActiveRecord::Encryption.configure \
      primary_key: "the primary key",
      deterministic_key: "the deterministic key",
      key_derivation_salt: "the salt",
      support_sha1_for_non_deterministic_encryption: true

    assert_predicate OtherEncryptedPost.type_for_attribute(:title).scheme.previous_schemes, :one?
  end

  test "binary data can be encrypted" do
    all_bytes = (0..255).map(&:chr).join
    assert_equal all_bytes, EncryptedBookWithBinary.create!(logo: all_bytes).logo
    assert_nil EncryptedBookWithBinary.create!(logo: nil).logo
    assert_equal "", EncryptedBookWithBinary.create!(logo: "").logo
  end

  test "binary data can be encrypted uncompressed" do
    low_bytes = (0..127).map(&:chr).join
    high_bytes = (128..255).map(&:chr).join
    assert_encrypted_attribute EncryptedBookWithBinary.create!(logo: low_bytes), :logo, low_bytes
    assert_encrypted_attribute EncryptedBookWithBinary.create!(logo: high_bytes), :logo, high_bytes
  end

  test "serialized binary data can be encrypted" do
    json_bytes = (32..127).map(&:chr)
    assert_encrypted_attribute EncryptedBookWithSerializedFirstBinary.create!(logo: json_bytes), :logo, json_bytes
    assert_encrypted_attribute EncryptedBookWithSerializedSecondBinary.create!(logo: json_bytes), :logo, json_bytes
  end

  test "can compress data with custom compressor" do
    name = "a" * 141
    assert EncryptedBookWithCustomCompressor.create!(name: name).name.start_with?("[compressed]")
  end

  test "type method returns cast type" do
    assert_equal :string, EncryptedBook.type_for_attribute(:name).type
    assert_equal :text, EncryptedPost.type_for_attribute(:body).type
  end

  test "encrypts normalized data" do
    assert_encrypted_attribute EncryptedBookNormalizedFirst.create!(name: "Book"), :name, "book"
    assert_encrypted_attribute EncryptedBookNormalizedSecond.create!(name: "Book"), :name, "book"
    assert_encrypted_attribute EncryptedBookNormalizedFirst.create!(logo: "Book"), :logo, "book"
    assert_encrypted_attribute EncryptedBookNormalizedSecond.create!(logo: "Book"), :logo, "book"
  end

  test "encrypts attribute data" do
    assert_encrypted_attribute EncryptedBookAttribute.create!(name: "2024-01-01"), :name, Date.new(2024, 1, 1)
  end

  private
    def build_derived_key_provider_with(hash_digest_class)
      ActiveRecord::Encryption.with_encryption_context(key_generator: ActiveRecord::Encryption::KeyGenerator.new(hash_digest_class: hash_digest_class)) do
        ActiveRecord::Encryption::DerivedSecretKeyProvider.new(ActiveRecord::Encryption.config.primary_key)
      end
    end

    class FailingKeyProvider
      def decryption_key(message) end

      def encryption_key
        raise ActiveRecord::Encryption::Errors::Encryption
      end
    end

    class BookThatWillFailToEncryptName < UnencryptedBook
      self.table_name = "encrypted_books"

      encrypts :name, key_provider: FailingKeyProvider.new
    end
end
