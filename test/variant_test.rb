require "test_helper"
require "database/setup"
require "active_storage/variant"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  setup do
    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "resized variation" do
    assert_match /racecar.jpg/, @blob.variant(resize: "100x100").processed.url
  end

  test "resized and monochrome variation" do
    assert_match /racecar.jpg/, @blob.variant(resize: "100x100", monochrome: true).processed.url
  end
end
