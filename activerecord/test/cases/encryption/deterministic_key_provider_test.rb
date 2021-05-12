# frozen_string_literal: true

require "cases/encryption/helper"

class ActiveRecord::Encryption::DeterministicKeyProviderTest < ActiveRecord::EncryptionTestCase
  test "will raise a configuration error when trying to configure multiple keys" do
    assert_raise ActiveRecord::Encryption::Errors::Configuration do
      ActiveRecord::Encryption::DeterministicKeyProvider.new([ "secret 1", "secret 2" ])
    end
  end
end
