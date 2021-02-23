require "cases/encryption/helper"
require "models/author"
require "models/post"

class ActiveRecord::Encryption::MassEncryptionTest < ActiveRecord::TestCase
  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
  end

  test "It encrypts everything" do
    posts = ActiveRecord::Encryption.without_encryption do
      3.times.collect { |index| EncryptedPost.create!(title: "Article #{index}", body: "Body #{index}") }
    end

    authors = ActiveRecord::Encryption.without_encryption do
      3.times.collect { |index| EncryptedAuthor.create!(name: "Author #{index}") }
    end

    ActiveRecord::Encryption::MassEncryption.new\
      .add(EncryptedPost, EncryptedAuthor)
      .encrypt

    (posts + authors).each { |model| assert_encrypted_record(model.reload) }
  end
end
