# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"
require "models/post_encrypted"

class ActiveRecord::Encryption::ContextsTest < ActiveRecord::EncryptionTestCase
  fixtures :posts

  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    @post = EncryptedPost.create!(title: "Some encrypted post title", body: "Some body")
    @title_cleartext = @post.title
    @title_ciphertext = @post.ciphertext_for(:title)
  end

  test ".with_encryption_context lets you override properties" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
      assert_equal @title_ciphertext, @post.reload.title

      @post.update!(title: "Some new title")
    end

    assert_equal "Some new title", @post.title_before_type_cast
  end

  test ".with_encryption_context will restore previous context properties when there is an error" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
      raise "Some error"
    end
  rescue
    assert_encrypted_attribute @post.reload, :title, @title_cleartext
  end

  test ".with_encryption_context can be nested multiple times" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: encryptor_1 = ActiveRecord::Encryption::NullEncryptor.new) do
      assert_equal encryptor_1, ActiveRecord::Encryption.encryptor

      ActiveRecord::Encryption.with_encryption_context(encryptor: encryptor_2 = ActiveRecord::Encryption::NullEncryptor.new) do
        assert_equal encryptor_2, ActiveRecord::Encryption.encryptor

        ActiveRecord::Encryption.with_encryption_context(encryptor: encryptor_3 = ActiveRecord::Encryption::NullEncryptor.new) do
          assert_equal encryptor_3, ActiveRecord::Encryption.encryptor
        end

        assert_equal encryptor_2, ActiveRecord::Encryption.encryptor
      end

      assert_equal encryptor_1, ActiveRecord::Encryption.encryptor
    end
  end

  test ".with_encryption_context can be nested, inner context inherit from outer context" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: encryptor_1 = ActiveRecord::Encryption::NullEncryptor.new) do
      ActiveRecord::Encryption.with_encryption_context(key_generator: key_generator = Object.new) do
        assert_equal(key_generator, ActiveRecord::Encryption.key_generator)
        assert_equal(encryptor_1, ActiveRecord::Encryption.encryptor)

        ActiveRecord::Encryption.with_encryption_context(key_provider: key_provider = Object.new) do
          assert_equal(key_generator, ActiveRecord::Encryption.key_generator)
          assert_equal(encryptor_1, ActiveRecord::Encryption.encryptor)
          assert_equal(key_provider, ActiveRecord::Encryption.key_provider)
        end
      end
    end
  end

  test "nested .with_encryption context when mixing string and symbols" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: encryptor_1 = ActiveRecord::Encryption::NullEncryptor.new) do
      ActiveRecord::Encryption.with_encryption_context("encryptor" => encryptor_2 = ActiveRecord::Encryption::NullEncryptor.new) do
        assert_equal encryptor_2, ActiveRecord::Encryption.encryptor

        assert_includes(ActiveRecord::Encryption.context.to_h.keys, :encryptor)
        assert_not_includes(ActiveRecord::Encryption.context.to_h.keys, "encryptor")
      end
      assert_equal encryptor_1, ActiveRecord::Encryption.encryptor
    end
  end

  test "nested .with_encryption_context values propagates when encrypting an attribute" do
    encryptor = Class.new do
      def binary?
        false
      end

      def encrypt(value, **)
        ActiveRecord::Encryption.message_serializer.dump("The encryptor was used.")
      end

      def decrypt(value, **)
        value
      end
    end.new

    message_serializer = Class.new do
      def dump(value)
        "#{value} The serializer was used."
      end
    end.new

    post = EncryptedPostNoCompression.create(title: "abc", body: "")

    ActiveRecord::Encryption.with_encryption_context(encryptor: encryptor) do
      ActiveRecord::Encryption.with_encryption_context(message_serializer: message_serializer) do
        post.update!(body: "<Will be replaced>")
      end
    end

    assert_equal("The encryptor was used. The serializer was used.", post.body)
  end

  test ".with_encryption_context uses properties from the default_context" do
    encryptor = ActiveRecord::Encryption::Encryptor.new
    ActiveRecord::Encryption.default_context.encryptor = encryptor

    ActiveRecord::Encryption.with_encryption_context({}) do
      assert_equal(encryptor, ActiveRecord::Encryption.encryptor)
    end
  end

  test ".with_encryption_context not explicitly passed properties doesn't override an attibute context property" do
    post = EncryptedPostNoCompression.create(title: "abc", body: "")

    ActiveRecord::Encryption.with_encryption_context({}) do
      post_body = "a" * (ActiveRecord::Encryption::Encryptor::THRESHOLD_TO_JUSTIFY_COMPRESSION + 1)
      post.update!(body: post_body)
    end

    body_ciphertext = post.ciphertext_for(:body)
    message = ActiveRecord::Encryption.message_serializer.load(body_ciphertext)
    assert_nil(message.headers.compressed)
  end

  test ".with_encryption_context overrides attribute's context" do
    post_body = "a" * (ActiveRecord::Encryption::Encryptor::THRESHOLD_TO_JUSTIFY_COMPRESSION + 1)
    post = EncryptedPostNoCompression.create(title: "", body: post_body)
    body_ciphertext = post.ciphertext_for(:body)

    message = ActiveRecord::Encryption.message_serializer.load(body_ciphertext)
    assert_nil(message.headers.compressed)

    ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::Encryptor.new(compress: true)) do
      new_post_body = "b" * (ActiveRecord::Encryption::Encryptor::THRESHOLD_TO_JUSTIFY_COMPRESSION + 1)
      post.update!(body: new_post_body)
    end

    new_body_ciphertext = post.ciphertext_for(:body)
    message = ActiveRecord::Encryption.message_serializer.load(new_body_ciphertext)
    assert(message.headers.compressed)
  end

  test ".without_encryption when attribute defines a custom context property" do
    post = EncryptedPostNoCompression.create(title: "", body: "Some body")
    body_ciphertext = post.ciphertext_for(:body)

    ActiveRecord::Encryption.without_encryption do
      assert_equal(body_ciphertext, post.reload.body)

      post.update!(body: "Some new body")
    end

    assert_not_encrypted_attribute post, :body, "Some new body"
  end

  test ".without_encryption won't decrypt or encrypt data automatically" do
    ActiveRecord::Encryption.without_encryption do
      assert_equal @title_ciphertext, @post.reload.title

      @post.update!(title: "Some new title")
    end

    assert_not_encrypted_attribute @post, :title, "Some new title"
  end

  test ".without_encryption doesn't raise on binary encoded data" do
    assert_nothing_raised do
      ActiveRecord::Encryption.without_encryption do
        EncryptedBook.create!(name: "Dune".encode(Encoding::BINARY))
      end
    end
  end

  test ".protecting_encrypted_data don't decrypt attributes automatically" do
    ActiveRecord::Encryption.protecting_encrypted_data do
      assert_equal @title_ciphertext, @post.reload.title
    end
  end

  test ".protecting_encrypted_data allows db-queries on deterministic attributes" do
    book = EncryptedBook.create! name: "Dune"

    ActiveRecord::Encryption.protecting_encrypted_data do
      assert_equal book, EncryptedBook.find_by(name: "Dune")
    end
  end

  test "can't encrypt or decrypt in protected mode" do
    ActiveRecord::Encryption.protecting_encrypted_data do
      assert_raises ActiveRecord::Encryption::Errors::Configuration do
        @post.encrypt
      end

      assert_raises ActiveRecord::Encryption::Errors::Configuration do
        @post.decrypt
      end
    end
  end

  test ".protecting_encrypted_data will raise a validation error when modifying encrypting attributes" do
    ActiveRecord::Encryption.protecting_encrypted_data do
      assert_raises ActiveRecord::RecordInvalid do
        @post.update!(title: "Some new title")
      end
    end
  end

  test ".protecting_encrypted_data works when an attribute uses a custom context" do
    post = EncryptedPostNoCompression.create(title: "", body: "foo")

    ActiveRecord::Encryption.protecting_encrypted_data do
      assert_raises ActiveRecord::RecordInvalid do
        post.update!(body: "Some new body")
      end
    end
  end
end
