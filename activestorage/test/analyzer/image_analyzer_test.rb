# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/image_analyzer"

class ActiveStorage::Analyzer::ImageAnalyzerTest < ActiveSupport::TestCase
  test "analyzing an image" do
    blob = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    metadata = blob.tap(&:analyze).metadata

    assert_equal 4104, metadata[:width]
    assert_equal 2736, metadata[:height]
  end
end
