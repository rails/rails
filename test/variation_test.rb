require "test_helper"
require "database/setup"
require "active_storage/variant"

class ActiveStorage::VariationTest < ActiveSupport::TestCase
  setup do
    @blob = ActiveStorage::Blob.create_after_upload! \
        filename: "racecar.jpg", content_type: "image/jpeg",
        io: File.open(File.expand_path("../fixtures/files/racecar.jpg", __FILE__))
  end

  test "resized variation" do
    assert_match /racecar.jpg/, @blob.variant(resize: "100x100").processed.url
  end

  test "resized and monochrome variation" do
    assert_match /racecar.jpg/, @blob.variant(resize: "100x100", monochrome: true).processed.url
  end
end
