# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/previewer/audio_previewer"

class ActiveStorage::Previewer::AudioPreviewerTest < ActiveSupport::TestCase
  test "previewing an MP3 audio" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")

    ActiveStorage::Previewer::AudioPreviewer.new(blob).preview do |attachable|
      assert_equal "image/jpeg", attachable[:content_type]
      assert_equal "audio.jpg", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 1280, image.width
      assert_equal 720, image.height
      assert_equal "image/jpeg", image.mime_type
    end
  end

  test "previewing an MP3 audio with options" do
    blob = create_file_blob(filename: "audio.mp3", content_type: "audio/mp3")

    filter_options = "color=c=blue[color];aformat=channel_layouts=mono,showwavespic=s=640x480:colors=white[wave];[color][wave]scale2ref[bg][fg];[bg][fg]overlay=format=auto"

    ActiveStorage::Previewer::AudioPreviewer.new(blob).preview(filter_options: filter_options) do |attachable|
      assert_equal "image/jpeg", attachable[:content_type]
      assert_equal "audio.jpg", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 640, image.width
      assert_equal 480, image.height
      assert_equal "image/jpeg", image.mime_type
    end
  end

  test "previewing a audio that can't be previewed" do
    blob = create_file_blob(filename: "report.pdf", content_type: "audio/mp4")

    assert_raises ActiveStorage::PreviewError do
      ActiveStorage::Previewer::VideoPreviewer.new(blob).preview
    end
  end
end
