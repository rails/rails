require "test_helper"
require "database/setup"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  setup do
    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "resized variation" do
    skip

    variant = @blob.variant(resize: "100x100").processed

    assert_match /racecar.jpg/, variant.url
    assert_same_image "racecar-100x100.jpg", variant
  end

  test "resized and monochrome variation" do
    skip

    variant = @blob.variant(resize: "100x100", monochrome: true).processed

    assert_match /racecar.jpg/, variant.url
    assert_same_image "racecar-100x100-monochrome.jpg", variant
  end
end
