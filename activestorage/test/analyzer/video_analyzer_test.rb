# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/analyzer/video_analyzer"

class ActiveStorage::Analyzer::VideoAnalyzerTest < ActiveSupport::TestCase
  test "analyzing a video" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert_equal 640, metadata[:width]
    assert_equal 480, metadata[:height]
    assert_equal [4, 3], metadata[:display_aspect_ratio]
    assert_equal 5.166648, metadata[:duration]
    assert_not_includes metadata, :angle
  end

  test "analyzing a rotated video" do
    blob = create_file_blob(filename: "rotated_video.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert_equal 480, metadata[:width]
    assert_equal 640, metadata[:height]
    assert_equal [4, 3], metadata[:display_aspect_ratio]
    assert_equal 5.227975, metadata[:duration]
    assert_equal 90, metadata[:angle]
  end

  test "analyzing a video with rectangular samples" do
    blob = create_file_blob(filename: "video_with_rectangular_samples.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert_equal 1280, metadata[:width]
    assert_equal 720, metadata[:height]
    assert_equal [16, 9], metadata[:display_aspect_ratio]
  end

  test "analyzing a video with an undefined display aspect ratio" do
    blob = create_file_blob(filename: "video_with_undefined_display_aspect_ratio.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert_equal 640, metadata[:width]
    assert_equal 480, metadata[:height]
    assert_nil metadata[:display_aspect_ratio]
  end

  test "analyzing a video without a video stream" do
    blob = create_file_blob(filename: "video_without_video_stream.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)
    assert_equal({ "analyzed" => true, "identified" => true }, metadata)
  end
end
