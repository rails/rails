require "cases/encryption/helper"

class EncryptedAttributeTypeTest < ActiveSupport::TestCase
  test "deterministic is true when some iv is set" do
    assert_not ActiveRecord::Encryption::EncryptedAttributeType.new.deterministic?

    assert ActiveRecord::Encryption::EncryptedAttributeType.new(deterministic: true).deterministic?
    assert_not ActiveRecord::Encryption::EncryptedAttributeType.new(deterministic: false).deterministic?
  end
end
