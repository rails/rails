# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "resized variation" do
    variant = @blob.variant(resize: "100x100").processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "resized and monochrome variation" do
    variant = @blob.variant(resize: "100x100", monochrome: true).processed
    assert_match(/racecar\.jpg/, variant.service_url)

    image = read_image(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/Gray/, image.colorspace)
  end
end
