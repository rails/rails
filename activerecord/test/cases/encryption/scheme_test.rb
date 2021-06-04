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

  test "validates primary_key is set for non deterministic encryption" do
    ActiveRecord::Encryption.config.primary_key = nil

    assert_raise ActiveRecord::Encryption::Errors::Configuration do
      declare_and_use_class
    end

    assert_nothing_raised do
      declare_and_use_class deterministic: true
    end
  end

  test "validates deterministic_key is set for non deterministic encryption" do
    ActiveRecord::Encryption.config.deterministic_key = nil

    assert_raise ActiveRecord::Encryption::Errors::Configuration do
      declare_and_use_class deterministic: true
    end

    assert_nothing_raised do
      declare_and_use_class
    end
  end

  test "validates key_derivation_salt is set" do
    ActiveRecord::Encryption.config.key_derivation_salt = nil

    assert_raise ActiveRecord::Encryption::Errors::Configuration do
      declare_and_use_class
    end
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
