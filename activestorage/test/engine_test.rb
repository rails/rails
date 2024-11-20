# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::EngineTest < ActiveSupport::TestCase
  test "all default content types are recognized by marcel" do
    ActiveStorage.variable_content_types.each do |content_type|
      assert_equal content_type, Marcel::Magic.new(content_type).type
    end

    ActiveStorage.web_image_content_types.each do |content_type|
      assert_equal content_type, Marcel::Magic.new(content_type).type
    end

    ActiveStorage.content_types_to_serve_as_binary.each do |content_type|
      assert_equal content_type, Marcel::Magic.new(content_type).type
    end

    ActiveStorage.content_types_allowed_inline.each do |content_type|
      assert_equal content_type, Marcel::Magic.new(content_type).type
    end
  end

  test "image/bmp is a default content type" do
    assert_includes ActiveStorage.variable_content_types, "image/bmp"
  end

  test "true is the default touch_attachment_records value" do
    assert_equal true, ActiveStorage.touch_attachment_records
  end
end
