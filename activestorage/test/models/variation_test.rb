# frozen_string_literal: true

require "test_helper"

class ActiveStorage::VariationTest < ActiveSupport::TestCase
  test "symbolizes string keys in transformations" do
    variation = ActiveStorage::Variation.new("resize_to_limit" => [100, 100])

    assert_equal({ resize_to_limit: [100, 100] }, variation.transformations)
  end

  test "variations have the same key for different types of the same transformation" do
    variation_a = ActiveStorage::Variation.new(resize_to_limit: [100, 100])
    variation_b = ActiveStorage::Variation.new("resize_to_limit" => [100, 100])

    assert_equal variation_a.key, variation_b.key
  end

  test "variations have the same digest for different types of the same transformation" do
    variation_a = ActiveStorage::Variation.new(resize_to_limit: [100, 100])
    variation_b = ActiveStorage::Variation.new("resize_to_limit" => [100, 100])

    assert_equal variation_a.digest, variation_b.digest
  end

  test "wrap returns a Variation unchanged" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100])

    assert_same variation, ActiveStorage::Variation.wrap(variation)
  end

  test "wrap builds a Variation from a transformations hash" do
    variation = ActiveStorage::Variation.wrap(resize_to_limit: [100, 100])

    assert_instance_of ActiveStorage::Variation, variation
    assert_equal({ resize_to_limit: [100, 100] }, variation.transformations)
  end

  test "wrap decodes a signed variation key" do
    key = ActiveStorage::Variation.encode(resize_to_limit: [100, 100])
    variation = ActiveStorage::Variation.wrap(key)

    assert_equal({ resize_to_limit: [100, 100] }, variation.transformations)
  end

  test "encode and decode round-trip transformations" do
    transformations = { resize_to_limit: [100, 100], colourspace: "b-w" }
    key = ActiveStorage::Variation.encode(transformations)

    assert_equal transformations, ActiveStorage::Variation.decode(key).transformations
  end

  test "key encodes transformations" do
    transformations = { resize_to_limit: [100, 100] }
    variation = ActiveStorage::Variation.new(transformations)

    assert_equal ActiveStorage::Variation.encode(transformations), variation.key
  end

  test "default_to fills in missing transformations" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100])
      .default_to(format: :png)

    assert_equal({ resize_to_limit: [100, 100], format: :png }, variation.transformations)
  end

  test "default_to does not override existing transformations" do
    variation = ActiveStorage::Variation.new(format: :jpg, resize_to_limit: [100, 100])
      .default_to(format: :png)

    assert_equal({ format: :jpg, resize_to_limit: [100, 100] }, variation.transformations)
  end

  test "format defaults to png" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100])

    assert_equal :png, variation.format
  end

  test "format accepts valid extensions" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100], format: :jpg)

    assert_equal :jpg, variation.format
  end

  test "format accepts uppercase string extensions" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100], format: "PNG")

    assert_equal "PNG", variation.format
  end

  test "format raises for invalid extensions" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100], format: :invalid)

    assert_raises(ArgumentError, match: /Invalid variant format/) do
      variation.format
    end
  end

  test "content_type is derived from format" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100], format: :jpg)

    assert_equal "image/jpeg", variation.content_type
  end

  test "content_type defaults to png" do
    variation = ActiveStorage::Variation.new(resize_to_limit: [100, 100])

    assert_equal "image/png", variation.content_type
  end
end
