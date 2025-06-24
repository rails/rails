# frozen_string_literal: true

require "cases/encryption/helper"
require "models/book"

class ActiveRecord::Encryption::SchemeTest < ActiveRecord::EncryptionTestCase
  test "validates config options when using encrypted attributes" do
    assert_invalid_declaration deterministic: false, ignore_case: true
    assert_invalid_declaration key: "1234", key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("my secret")
    assert_invalid_declaration compress: false, compressor: Zlib
    assert_invalid_declaration compressor: Zlib, encryptor: ActiveRecord::Encryption::Encryptor.new

    assert_valid_declaration deterministic: true
    assert_valid_declaration key: "1234"
    assert_valid_declaration key_provider: ActiveRecord::Encryption::DerivedSecretKeyProvider.new("my secret")
  end

  test "should create a encryptor well when compressor is given" do
    MyCompressor = Class.new do
      def self.deflate(data)
        "deflated #{data}"
      end

      def self.inflate(data)
        data.sub("deflated ", "")
      end
    end

    type = declare_encrypts_with compressor: MyCompressor

    assert_equal MyCompressor, type.scheme.to_h[:encryptor].compressor
  end

  test "should create a encryptor well when compress is false" do
    type = declare_encrypts_with compress: false

    assert_not type.scheme.to_h[:encryptor].compress?
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

    def declare_encrypts_with(options)
      Class.new(Book) do
        encrypts :name, **options
      end.type_for_attribute(:name)
    end
end
