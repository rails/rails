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

  test "monochrome variation" do
    variant = @blob.variant(monochrome: true).processed

    image = read_image_variant(variant)
    assert_match(/Gray/, image.colorspace)
  end

  test "rotate variation" do
    variant = @blob.variant(rotate: "-90").processed

    image = read_image_variant(variant)
    assert_equal 2736, image.width
    assert_equal 4104, image.height
  end
end
