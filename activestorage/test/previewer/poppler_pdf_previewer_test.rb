# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/previewer/poppler_pdf_previewer"

class ActiveStorage::Previewer::PopplerPDFPreviewerTest < ActiveSupport::TestCase
  test "previewing a PDF document" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    ActiveStorage::Previewer::PopplerPDFPreviewer.new(blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "report.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 612, image.width
      assert_equal 792, image.height
    end
  end

  test "previewing a cropped PDF document" do
    blob = create_file_blob(filename: "cropped.pdf", content_type: "application/pdf")
    ActiveStorage::Previewer::PopplerPDFPreviewer.new(blob).preview do |attachable|
      assert_equal "image/png", attachable[:content_type]
      assert_equal "cropped.png", attachable[:filename]

      image = MiniMagick::Image.read(attachable[:io])
      assert_equal 430, image.width
      assert_equal 145, image.height
    end
  end
end
