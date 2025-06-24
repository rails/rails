# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::RepresentationTest < ActiveSupport::TestCase
  test "representing an image" do
    blob = create_file_blob
    representation = blob.representation(resize_to_limit: [100, 100]).processed

    image = read_image(representation.image)
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "representing a PDF" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    representation = blob.representation(resize_to_limit: [640, 280]).processed

    image = read_image(representation.image)
    assert_equal 612, image.width
    assert_equal 792, image.height
  end

  test "representing a PDF-based Illustrator file" do
    blob = create_file_blob(fixture: "report.pdf", filename: "file.ai", content_type: "application/illustrator")
    representation = blob.representation(resize_to_limit: [640, 280]).processed

    image = read_image(representation.image)
    assert_equal 612, image.width
    assert_equal 792, image.height
  end

  test "representing an MP4 video" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")
    representation = blob.representation(resize_to_limit: [640, 280]).processed

    image = read_image(representation.image)
    assert_equal 640, image.width
    assert_equal 480, image.height
  end

  test "representing an unrepresentable blob" do
    blob = create_blob
    assert_raises ActiveStorage::UnrepresentableError, match: /blob with ID=\d+ and content_type=text\/plain/ do
      blob.representation resize_to_limit: [100, 100]
    end
  end
end
