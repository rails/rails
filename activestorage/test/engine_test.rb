# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::EngineTest < ActiveSupport::TestCase
  test "all default content types are recognized by mini_mime" do
    exceptions = ["image/bmp"] # see https://github.com/discourse/mini_mime/pull/45, once mini_mime is updated this can be removed

    ActiveStorage.variable_content_types.each do |content_type|
      next if exceptions.include?(content_type) # remove this line when there is no exceptions

      assert_equal content_type, MiniMime.lookup_by_content_type(content_type)&.content_type
    end

    ActiveStorage.web_image_content_types.each do |content_type|
      next if exceptions.include?(content_type) # remove this line when there is no exceptions

      assert_equal content_type, MiniMime.lookup_by_content_type(content_type)&.content_type
    end

    ActiveStorage.content_types_to_serve_as_binary.each do |content_type|
      next if exceptions.include?(content_type) # remove this line when there is no exceptions

      assert_equal content_type, MiniMime.lookup_by_content_type(content_type)&.content_type
    end

    ActiveStorage.content_types_allowed_inline.each do |content_type|
      next if exceptions.include?(content_type) # remove this line when there is no exceptions

      assert_equal content_type, MiniMime.lookup_by_content_type(content_type)&.content_type
    end
  end

  test "image/bmp is a default content type" do
    assert_includes ActiveStorage.variable_content_types, "image/bmp"
  end
end
