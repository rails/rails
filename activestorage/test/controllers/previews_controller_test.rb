# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::PreviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
  end

  test "showing preview inline" do
    get rails_blob_preview_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert @blob.preview_image.attached?
    assert_redirected_to(/report\.png\?.*disposition=inline/)

    image = read_image(@blob.preview_image.variant(resize: "100x100"))
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "showing preview with invalid signed blob ID" do
    get rails_blob_preview_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_response :not_found
  end
end
