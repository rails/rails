# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::ImageTagTest < ActionView::TestCase
  tests ActionView::Helpers::AssetTagHelper

  test "model delivery methods" do
    blob = create_file_blob filename: "racecar.jpg"

    user = User.new(name: "Tom", proxied_image: blob)

    assert_match "blobs_proxy", image_tag(user.proxied_image)
    assert_match "representations_proxy", image_tag(user.proxied_image.variant(resize: "100x100"))
  end

  test "model delivery method on preview" do
    pdf_blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"

    user = User.new(name: "Tom", proxied_image: pdf_blob)

    assert_match "representations_proxy", image_tag(user.proxied_image.preview(resize_to_fit: [100, 100]))
  end
end
