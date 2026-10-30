# frozen_string_literal: true

require "test_helper"

require "active_storage/transformers/image_magick"

class ActiveStorage::Transformers::ImageProcessingTransformerTest < ActiveSupport::TestCase
  setup do
    @transformer_class = ActiveStorage::Transformers::ImageMagick
  end

  test "combine_options raises ArgumentError" do
    transformer = @transformer_class.new(combine_options: { resize: "100x100" })

    assert_raises(ArgumentError, match: /combine_options/) do
      transformer.send(:operations)
    end
  end

  test "combine_options with a string key raises ArgumentError" do
    transformer = @transformer_class.new("combine_options" => { resize: "100x100" })

    assert_raises(ArgumentError, match: /combine_options/) do
      transformer.send(:operations)
    end
  end

  test "blank transformation arguments are omitted from operations" do
    transformer = @transformer_class.new(resize_to_limit: [100, 100], colourspace: "")

    assert_equal [[:resize_to_limit, [100, 100]]], transformer.send(:operations)
  end

  test "nil transformation arguments are omitted from operations" do
    transformer = @transformer_class.new(resize_to_limit: [100, 100], rotate: nil)

    assert_equal [[:resize_to_limit, [100, 100]]], transformer.send(:operations)
  end

  test "supported transformations are included in operations" do
    transformer = @transformer_class.new(resize_to_limit: [100, 100], colourspace: "b-w")

    operations = transformer.send(:operations)

    assert_equal 2, operations.size
    assert_includes operations, [:resize_to_limit, [100, 100]]
    assert_includes operations, [:colourspace, "b-w"]
  end

  test "unsupported transformation methods raise UnsupportedImageProcessingMethod" do
    transformer = @transformer_class.new(system: "touch /tmp/dangerous")

    assert_raises(ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod) do
      transformer.send(:operations)
    end
  end
end
