# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book_encrypted"
require "models/post_encrypted"

class ActiveRecord::Encryption::ContextsTest < ActiveRecord::EncryptionTestCase
  fixtures :posts

  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    @post = EncryptedPost.create!(title: "Some encrypted post title", body: "Some body", raw_body: "some raw body")
    @clean_title = @post.title
    @clean_raw_body = @post.raw_body
  end

  test ".with_encryption_context lets you override properties" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
      assert_protected_encrypted_attribute(@post, :title, @clean_title)
      @post.update!(title: "Some new title")
    end

    assert_equal "Some new title", @post.title
  end

  test ".with_encryption_context will restore previous context properties when there is an error" do
    ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
      raise "Some error"
    end
  rescue
    assert_encrypted_attribute @post.reload, :title, @clean_title
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

  test ".with_encryption_context raises an encoding error for binary data that cannot be encoded as a string" do
    binary_data = Base64.strict_decode64("AhufVG0kg/az30AJ7xiD7JyuxwdSsfMsbTDy36q0pj7YCQ7Nl/H0Vg==")

    assert_raises Encoding::UndefinedConversionError do
      ActiveRecord::Encryption.with_encryption_context(encryptor: ActiveRecord::Encryption::NullEncryptor.new) do
        assert_protected_encrypted_attribute(@post, :raw_body, @clean_raw_body)

        @post.update!(raw_body: binary_data)
      end
    end
  end

  test ".without_encryption won't change serialization type" do
    binary_data = Base64.strict_decode64("AhufVG0kg/az30AJ7xiD7JyuxwdSsfMsbTDy36q0pj7YCQ7Nl/H0Vg==")

    ActiveRecord::Encryption.without_encryption do
      assert_protected_encrypted_attribute(@post, :raw_body, @clean_raw_body)

      @post.update!(raw_body: binary_data)
    end

    assert_equal binary_data, @post.raw_body
  end

  test ".without_encryption won't decrypt or encrypt data automatically" do
    ActiveRecord::Encryption.without_encryption do
      assert_protected_encrypted_attribute(@post, :title, @clean_title)

      @post.update!(title: "Some new title")
    end

    assert_equal "Some new title", @post.title
  end

  test ".protecting_encrypted_data don't decrypt attributes automatically" do
    ActiveRecord::Encryption.protecting_encrypted_data do
      assert_protected_encrypted_attribute(@post, :title, @clean_title)
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

  private
    def assert_protected_encrypted_attribute(model, attribute_name, clean_value)
      assert_equal model.reload.ciphertext_for(attribute_name), model.public_send(attribute_name)
      assert_not_equal clean_value, model.ciphertext_for(:title)
    end
end
