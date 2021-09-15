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
    assert metadata[:audio]
    assert metadata[:video]
    assert_not_includes metadata, :angle
  end

  test "analyzing a rotated video" do
    blob = create_file_blob(filename: "rotated_video.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert_equal 480, metadata[:width]
    assert_equal 640, metadata[:height]
    assert_equal [4, 3], metadata[:display_aspect_ratio]
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

  test "analyzing a video with a container-specified duration" do
    blob = create_file_blob(filename: "video.webm", content_type: "video/webm")
    metadata = extract_metadata_from(blob)

    assert_equal 640, metadata[:width]
    assert_equal 480, metadata[:height]
    assert_equal 5.229000, metadata[:duration]
    assert metadata[:audio]
    assert metadata[:video]
  end

  test "analyzing a video without a video stream" do
    blob = create_file_blob(filename: "video_without_video_stream.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert_not_includes metadata, :width
    assert_not_includes metadata, :height
    assert_equal 1.022000, metadata[:duration]
    assert_not metadata[:video]
    assert metadata[:audio]
  end

  test "analyzing a video without an audio stream" do
    blob = create_file_blob(filename: "video_without_audio_stream.mp4", content_type: "video/mp4")
    metadata = extract_metadata_from(blob)

    assert metadata[:video]
    assert_not metadata[:audio]
  end

  test "instrumenting analysis" do
    events = subscribe_events_from("analyze.active_storage")

    blob = create_file_blob(filename: "video_without_audio_stream.mp4", content_type: "video/mp4")
    blob.analyze

    assert_equal 1, events.size
    assert_equal({ analyzer: "ffprobe" }, events.first.payload)
  end
end
