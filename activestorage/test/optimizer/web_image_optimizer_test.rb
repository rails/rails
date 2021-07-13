# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/optimizer/web_image_optimizer"

class ActiveStorage::Optimizer::WebImageOptimizerTest < ActiveSupport::TestCase
  test "transforming a web image" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    optimizer = ActiveStorage::Optimizer::WebImageOptimizer.new(blob)

    assert_equal "jpg", optimizer.transformations[:format]
  end

  test "transforming a variable image" do
    blob = create_file_blob(filename: "racecar.tif", content_type: "image/tiff")
    optimizer = ActiveStorage::Optimizer::WebImageOptimizer.new(blob)

    assert_equal :png, optimizer.transformations[:format]
  end
end
