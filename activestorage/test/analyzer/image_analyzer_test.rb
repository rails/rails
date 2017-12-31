# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/image_analyzer"

class ActiveStorage::Analyzer::ImageAnalyzerTest < ActiveSupport::TestCase
  test "analyzing a JPEG image" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    metadata = blob.tap(&:analyze).metadata

    assert_equal 4104, metadata[:width]
    assert_equal 2736, metadata[:height]
  end

  test "analyzing an SVG image without an XML declaration" do
    blob = create_file_blob(filename: "icon.svg", content_type: "image/svg+xml")
    metadata = blob.tap(&:analyze).metadata

    assert_equal 792, metadata[:width]
    assert_equal 584, metadata[:height]
  end
end
