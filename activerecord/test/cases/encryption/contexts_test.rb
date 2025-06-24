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
end
