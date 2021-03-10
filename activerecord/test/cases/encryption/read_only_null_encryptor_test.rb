# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::ReadOnlyNullEncryptorTest < ActiveSupport::TestCase
  setup do
    @encryptor = ActiveRecord::Encryption::ReadOnlyNullEncryptor.new
  end

  test "decrypt returns the encrypted message" do
    assert "some text", @encryptor.decrypt("some text")
  end

  test "encrypt raises an Encryption" do
    assert_raises ActiveRecord::Encryption::Errors::Encryption do
      @encryptor.encrypt("some text")
    end
  end
end
