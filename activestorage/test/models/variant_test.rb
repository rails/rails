# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantTest < ActiveSupport::TestCase
  setup do
    @blob = create_image_blob filename: "racecar.jpg"
  end

  test "service_url" do
    assert_match(/racecar\.jpg/, @blob.variant({}).service_url)
  end

  test "resized variation" do
    variant = @blob.variant(resize: "100x100").processed

    image = read_image_variant(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "resized and monochrome variation" do
    variant = @blob.variant(resize: "100x100", monochrome: true).processed

    image = read_image_variant(variant)
    assert_equal 100, image.width
    assert_equal 67, image.height
    assert_match(/Gray/, image.colorspace)
  end
end
