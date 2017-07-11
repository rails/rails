require "test_helper"
require "database/setup"
require "active_storage/variant"

class ActiveStorage::VariationTest < ActiveSupport::TestCase
  test "square variation" do
    blob = ActiveStorage::Blob.create_after_upload! \
      io: File.open(File.expand_path("../fixtures/files/racecar.jpg", __FILE__)), filename: "racecar.jpg", content_type: "image/jpeg"

    variation_key = ActiveStorage::Variant.encode_key(resize: "500x500")

    variant = ActiveStorage::Variant.lookup(blob_key: blob.key, variation_key: variation_key)

    assert_match /racecar.jpg/, variant.url
  end
end
