# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

require "active_storage/previewer/video_previewer"

class ActiveStorage::Previewer::VideoPreviewerTest < ActiveSupport::TestCase
  test "previewing an MP4 video for main" do
    blob = create_main_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage::Previewer::VideoPreviewer.new(blob).preview do |attachable|
      assert_equal "image/jpeg", attachable[:content_type]
      assert_equal "video.jpg", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 640, image.width
      assert_equal 480, image.height
      assert_equal "image/jpeg", Marcel::Magic.by_extension(image.type).type
    end
  end

  test "previewing an MP4 video for animals" do
    blob = create_animals_file_blob(filename: "video.mp4", content_type: "video/mp4")

    ActiveStorage::Previewer::VideoPreviewer.new(blob).preview do |attachable|
      assert_equal "image/jpeg", attachable[:content_type]
      assert_equal "video.jpg", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 640, image.width
      assert_equal 480, image.height
      assert_equal "image/jpeg", Marcel::Magic.by_extension(image.type).type
    end
  end

  test "previewing a video that can't be previewed for main" do
    blob = create_main_file_blob(filename: "report.pdf", content_type: "video/mp4")

    assert_raises ActiveStorage::PreviewError do
      ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
    end
  end

  test "previewing a video that can't be previewed for animals" do
    blob = create_animals_file_blob(filename: "report.pdf", content_type: "video/mp4")

    assert_raises ActiveStorage::PreviewError do
      ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
    end
  end
end
