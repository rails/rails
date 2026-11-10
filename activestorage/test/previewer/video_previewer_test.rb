# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/previewer/video_previewer"

class ActiveStorage::Previewer::VideoPreviewerTest < ActiveSupport::TestCase
  setup do
    if !ENV["BUILDKITE"] && !system("command", "-v", ActiveStorage.paths[:ffmpeg] || "ffmpeg", out: File::NULL)
      skip("ffmpeg isn't available")
    end
  end

  test "previewing an MP4 video" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage::Previewer::VideoPreviewer.new(blob).preview do |attachable|
      assert_equal "image/jpeg", attachable[:content_type]
      assert_equal "video.jpg", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 640, image.width
      assert_equal 480, image.height
      assert_equal "image/jpeg", Marcel::Magic.by_extension(image.type).type
    end
  end

  test "previewing videos in other common formats" do
    { "video.webm" => "video/webm", "rotated_hdr_video.mov" => "video/quicktime", "video_with_duplicate_tags.avi" => "video/x-msvideo" }.each do |fixture, content_type|
      blob = create_file_blob(filename: fixture, content_type: content_type)

      ActiveStorage::Previewer::VideoPreviewer.new(blob).preview do |attachable|
        assert_equal "image/jpeg", Marcel::Magic.by_extension(MiniMagick::Image.read(attachable[:io]).type).type, fixture
      end
    end
  end

  test "previewing a playlist declared as a video" do
    blob = create_playlist_blob(referencing: "video_with_duplicate_tags.avi", filename: "video.m3u8", content_type: "video/mp4")

    assert_raises ActiveStorage::PreviewError do
      ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
    end
  end

  test "previewing a playlist declared as a video with input arguments that allow it" do
    blob = create_playlist_blob(referencing: "video_with_duplicate_tags.avi", filename: "video.m3u8", content_type: "video/mp4")

    ActiveStorage.with(video_preview_input_arguments: "-format_whitelist hls,avi") do
      assert_raises ActiveStorage::PreviewError do
        ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
      end
    end
  end

  test "previewing a video whose format is not allowed" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage.with(ffmpeg_allowed_formats: %w[ matroska ]) do
      assert_raises ActiveStorage::PreviewError do
        ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
      end
    end
  end

  test "previewing a video whose format is not allowed by a comma-separated list" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage.with(ffmpeg_allowed_formats: "matroska,avi") do
      assert_raises ActiveStorage::PreviewError do
        ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
      end
    end
  end

  test "previewing a video when no formats are allowed" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage.with(ffmpeg_allowed_formats: []) do
      assert_raises ActiveStorage::PreviewError do
        ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
      end
    end
  end

  test "previewing a video that the input arguments exclude" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage.with(video_preview_input_arguments: "-codec_whitelist none") do
      assert_raises ActiveStorage::PreviewError do
        ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
      end
    end
  end

  test "previewing a video that can't be previewed" do
    blob = create_file_blob(filename: "report.pdf", content_type: "video/mp4")

    assert_raises ActiveStorage::PreviewError do
      ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
    end
  end
end
