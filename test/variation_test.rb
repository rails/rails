require "test_helper"
require "database/setup"
require "active_storage/variant"

class ActiveStorage::VariationTest < ActiveSupport::TestCase
  test "square variation" do
    blob = ActiveStorage::Blob.create_after_upload! \
      io: File.open(File.expand_path("../fixtures/files/racecar.jpg", __FILE__)), filename: "racecar.jpg", content_type: "image/jpeg"

    assert_match /racecar.jpg/, blob.variant(resize: "100x100").processed.url
  end
end
