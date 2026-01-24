# frozen_string_literal: true

require "cases/encryption/helper"
require "models/post_encrypted"

class ActiveRecord::Encryption::ConcurrencyTest < ActiveRecord::EncryptionTestCase
  setup do
    ActiveRecord::Encryption.config.support_unencrypted_data = true
  end

  test "models can be encrypted and decrypted in different threads concurrently" do
    3.times.collect { |index| thread_encrypting_and_decrypting("thread #{index}") }.each(&:join)
  end

  def thread_encrypting_and_decrypting(thread_label)
    EncryptedPost.insert_all 10.times.collect { |index| { title: "Article #{index} (#{thread_label})", body: "Body #{index} (#{thread_label})" } }
    posts = EncryptedPost.last(10)

    Thread.new do
      posts.each.with_index do |article, index|
        assert_encrypted_attribute article, :title, "Article #{index} (#{thread_label})"
        article.decrypt
        assert_not_encrypted_attribute article, :title, "Article #{index} (#{thread_label})"
      end
    end
  end
end
