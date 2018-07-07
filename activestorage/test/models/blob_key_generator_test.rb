# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::BlobKeyGeneratorTest < ActiveSupport::TestCase
  setup do
    @blob = create_blob(filename: "original.txt")
  end

  teardown { ActiveStorage::Blob.all.each(&:purge) }

  test "generate blob key according to blob key_format" do
    @blob.key_format = "system/:extension/:hash/:filename.:extension"

    key = ActiveStorage::BlobKeyGenerator.new(@blob).generate

    assert_match /system\/txt\/[a-zA-Z0-9]+\/original\.txt/, key
  end

  test "with invalid token it raises error" do
    @blob.key_format = "system/:invalid_key"

    error = assert_raises ActiveStorage::InvalidKeyTokenError do
      ActiveStorage::BlobKeyGenerator.new(@blob).generate
    end

    assert_equal "Invalid token for key_format: :invalid_key", error.message
  end
end
