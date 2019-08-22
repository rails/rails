# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::PreviewTest < ActiveSupport::TestCase
  test "previewing a PDF" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    preview = blob.preview(resize: "640x280").processed

    assert_predicate preview.image, :attached?
    assert_equal "report.png", preview.image.filename.to_s
    assert_equal "image/png", preview.image.content_type

    image = read_image(preview.image)
    assert_equal 612, image.width
    assert_equal 792, image.height
  end

  test "previewing an MP4 video" do
    blob = create_file_blob(filename: "video.mp4", content_type: "video/mp4")
    preview = blob.preview(resize: "640x280").processed

    assert_predicate preview.image, :attached?
    assert_equal "video.jpg", preview.image.filename.to_s
    assert_equal "image/jpeg", preview.image.content_type

    image = read_image(preview.image)
    assert_equal 640, image.width
    assert_equal 480, image.height
  end

  test "previewing an unpreviewable blob" do
    blob = create_file_blob

    assert_raises ActiveStorage::UnpreviewableError do
      blob.preview resize: "640x280"
    end
  end

  test "change delivery on instance" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    preview = blob.preview(resize: "640x280").processed

    assert_equal preview.url(:redirect), Rails.application.routes.url_helpers.route_for(:rails_blob_representation, blob.signed_id, preview.variation.key, blob.filename, only_path: true)
    assert_equal preview.url(:proxy), Rails.application.routes.url_helpers.route_for(:rails_blob_representation_proxy, blob.signed_id, preview.variation.key, blob.filename, only_path: true)
  end
end
