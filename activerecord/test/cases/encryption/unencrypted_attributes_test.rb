# frozen_string_literal: true

require "cases/encryption/helper"
require "models/post_encrypted"

class ActiveRecord::Encryption::UnencryptedAttributesTest < ActiveRecord::TestCase
  test "when :support_unencrypted_data is off, it works with unencrypted attributes normally" do
    ActiveRecord::Encryption.config.support_unencrypted_data = true

    post = ActiveRecord::Encryption.without_encryption { EncryptedPost.create!(title: "The Starfleet is here!", body: "take cover!") }
    assert_not_encrypted_attribute(post, :title, "The Starfleet is here!")

    # It will encrypt on saving
    post.update! title: "Other title"
    assert_encrypted_attribute(post.reload, :title, "Other title")
  end

  test "when :support_unencrypted_data is on, it won't work with unencrypted attributes" do
    ActiveRecord::Encryption.config.support_unencrypted_data = false

    post = ActiveRecord::Encryption.without_encryption { EncryptedPost.create!(title: "The Starfleet is here!", body: "take cover!") }

    assert_raises ActiveRecord::Encryption::Errors::Decryption do
      post.title
    end
  end
end
