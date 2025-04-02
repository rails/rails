# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

require "active_storage/analyzer/video_analyzer"

class ActiveStorage::Analyzer::VideoAnalyzerTest < ActiveSupport::TestCase
  test "analyzing a video" do
    main_blob = create_main_file_blob(filename: "video.mp4", content_type: "video/mp4")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "video.mp4", content_type: "video/mp4")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 640, main_metadata[:width]
    assert_equal 480, main_metadata[:height]
    assert_equal [4, 3], main_metadata[:display_aspect_ratio]
    assert_equal 5.166648, main_metadata[:duration]
    assert main_metadata[:audio]
    assert main_metadata[:video]
    assert_not_includes main_metadata, :angle

    assert_equal 640, animals_metadata[:width]
    assert_equal 480, animals_metadata[:height]
    assert_equal [4, 3], animals_metadata[:display_aspect_ratio]
    assert_equal 5.166648, animals_metadata[:duration]
    assert animals_metadata[:audio]
    assert animals_metadata[:video]
    assert_not_includes animals_metadata, :angle
  end

  test "analyzing a rotated video" do
    main_blob = create_main_file_blob(filename: "rotated_video.mp4", content_type: "video/mp4")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "rotated_video.mp4", content_type: "video/mp4")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 480, main_metadata[:width]
    assert_equal 640, main_metadata[:height]
    assert_equal [4, 3], main_metadata[:display_aspect_ratio]
    assert_includes [90, -90], main_metadata[:angle]

    assert_equal 480, animals_metadata[:width]
    assert_equal 640, animals_metadata[:height]
    assert_equal [4, 3], animals_metadata[:display_aspect_ratio]
    assert_includes [90, -90], animals_metadata[:angle]
  end

  test "analyzing a rotated HDR video" do
    main_blob = create_main_file_blob(filename: "rotated_hdr_video.mov", content_type: "video/quicktime")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "rotated_hdr_video.mov", content_type: "video/quicktime")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 1080.0, main_metadata[:width]
    assert_equal 1920.0, main_metadata[:height]
    assert_includes [90, -90], main_metadata[:angle]

    assert_equal 1080.0, animals_metadata[:width]
    assert_equal 1920.0, animals_metadata[:height]
    assert_includes [90, -90], animals_metadata[:angle]
  end

  test "analyzing a video with rectangular samples" do
    main_blob = create_main_file_blob(filename: "video_with_rectangular_samples.mp4", content_type: "video/mp4")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "video_with_rectangular_samples.mp4", content_type: "video/mp4")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 1280, main_metadata[:width]
    assert_equal 720, main_metadata[:height]
    assert_equal [16, 9], main_metadata[:display_aspect_ratio]

    assert_equal 1280, animals_metadata[:width]
    assert_equal 720, animals_metadata[:height]
    assert_equal [16, 9], animals_metadata[:display_aspect_ratio]
  end

  test "analyzing a video with an undefined display aspect ratio" do
    main_blob = create_main_file_blob(filename: "video_with_undefined_display_aspect_ratio.mp4", content_type: "video/mp4")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "video_with_undefined_display_aspect_ratio.mp4", content_type: "video/mp4")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 640, main_metadata[:width]
    assert_equal 480, main_metadata[:height]
    assert_nil main_metadata[:display_aspect_ratio]

    assert_equal 640, animals_metadata[:width]
    assert_equal 480, animals_metadata[:height]
    assert_nil animals_metadata[:display_aspect_ratio]
  end

  test "analyzing a video with a container-specified duration" do
    main_blob = create_main_file_blob(filename: "video.webm", content_type: "video/webm")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "video.webm", content_type: "video/webm")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_equal 640, main_metadata[:width]
    assert_equal 480, main_metadata[:height]
    assert_equal 5.229000, main_metadata[:duration]
    assert main_metadata[:audio]
    assert main_metadata[:video]

    assert_equal 640, animals_metadata[:width]
    assert_equal 480, animals_metadata[:height]
    assert_equal 5.229000, animals_metadata[:duration]
    assert animals_metadata[:audio]
    assert animals_metadata[:video]
  end

  test "analyzing a video without a video stream" do
    main_blob = create_main_file_blob(filename: "video_without_video_stream.mp4", content_type: "video/mp4")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "video_without_video_stream.mp4", content_type: "video/mp4")
    animals_metadata = extract_metadata_from(animals_blob)

    assert_not_includes main_metadata, :width
    assert_not_includes main_metadata, :height
    assert_includes 1.000000..1.022000, main_metadata[:duration]
    assert_not main_metadata[:video]
    assert main_metadata[:audio]

    assert_not_includes animals_metadata, :width
    assert_not_includes animals_metadata, :height
    assert_includes 1.000000..1.022000, animals_metadata[:duration]
    assert_not animals_metadata[:video]
    assert animals_metadata[:audio]
  end

  test "analyzing a video without an audio stream" do
    main_blob = create_main_file_blob(filename: "video_without_audio_stream.mp4", content_type: "video/mp4")
    main_metadata = extract_metadata_from(main_blob)

    animals_blob = create_animals_file_blob(filename: "video_without_audio_stream.mp4", content_type: "video/mp4")
    animals_metadata = extract_metadata_from(animals_blob)

    assert main_metadata[:video]
    assert_not main_metadata[:audio]

    assert animals_metadata[:video]
    assert_not animals_metadata[:audio]
  end

  test "instrumenting analysis" do
    main_blob = create_main_file_blob(filename: "video.mp4", content_type: "video/mp4")
    animals_blob = create_animals_file_blob(filename: "video.mp4", content_type: "video/mp4")

    assert_notifications_count("analyze.active_storage", 2) do
      assert_notification("analyze.active_storage", analyzer: "ffprobe") do
        main_blob.analyze
        animals_blob.analyze
      end
    end
  end
end
