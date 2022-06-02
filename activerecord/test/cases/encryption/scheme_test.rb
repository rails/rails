# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book"

class ActiveRecord::Encryption::SchemeTest < ActiveRecord::EncryptionTestCase
  test "validates config options when declaring encrypted attributes" do
    assert_invalid_declaration deterministic: false, ignore_case: true
    assert_invalid_declaration key: "1234", key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("my secret")

    assert_valid_declaration deterministic: true
    assert_valid_declaration key: "1234"
    assert_valid_declaration key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("my secret")
  end

  private
    def assert_invalid_declaration(**options)
      assert_raises ActiveRecord::Encryption::Errors::Configuration do
        declare_encrypts_with(options)
      end
    end

    def assert_valid_declaration(**options)
      assert_nothing_raised do
        declare_encrypts_with(options)
      end
    end

    def declare_and_use_class(**options)
      encrypted_book_class = Class.new(Book) do
        encrypts :name, **options
      end

      encrypted_book_class.create! name: "Some name"
    end

    def declare_encrypts_with(options)
      Class.new(Book) do
        encrypts :name, **options
      end
    end
end
