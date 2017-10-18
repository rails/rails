# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/previewer/video_previewer"

class ActiveStorage::Previewer::VideoPreviewerTest < ActiveSupport::TestCase
  setup do
    @blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")
  end

  test "previewing an MP4 video" do
    ActiveStorage::Previewer::VideoPreviewer.new(@blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "video.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 640, image.width
      assert_equal 480, image.height
    end
  end
end
