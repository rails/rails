# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/previewer/mupdf_previewer"

class ActiveStorage::Previewer::MuPDFPreviewerTest < ActiveSupport::TestCase
  test "previewing a PDF document" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")

    ActiveStorage::Previewer::MuPDFPreviewer.new(blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "report.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 612, image.width
      assert_equal 792, image.height
    end
  end

  test "previewing a cropped PDF document" do
    blob = create_file_blob(filename: "cropped.pdf", content_type: "application/pdf")

    ActiveStorage::Previewer::MuPDFPreviewer.new(blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "cropped.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 430, image.width
      assert_equal 145, image.height
    end
  end

  test "previewing an Illustrator document that's a PDF subtype" do
    blob = create_file_blob(fixture: "report.pdf", filename: "file.ai", content_type: "application/illustrator")

    ActiveStorage::Previewer::MuPDFPreviewer.new(blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "file.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 612, image.width
      assert_equal 792, image.height
    end
  end

  test "previewing a PDF that can't be previewed" do
    blob = create_file_blob(filename: "video.mp4", content_type: "application/pdf")

    assert_raises ActiveStorage::PreviewError do
      ActiveStorage::Previewer::MuPDFPreviewer.new(blob).preview
    end
  end
end
