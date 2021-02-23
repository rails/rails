require "cases/encryption/helper"

class ActiveRecord::Encryption::NullEncryptorTest < ActiveSupport::TestCase
  setup do
    @encryptor = ActiveRecord::Encryption::NullEncryptor.new
  end

  test "encrypt returns the passed data" do
    assert_equal "Some data", @encryptor.encrypt("Some data")
  end

  test "decrypt returns the passed data" do
    assert_equal "Some data", @encryptor.decrypt("Some data")
  end

  test "encrypted? returns false" do
    assert_not @encryptor.encrypted?("Some data")
  end
end
