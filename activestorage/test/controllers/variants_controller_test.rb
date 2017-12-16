# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::VariantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "showing variant inline" do
    get rails_blob_variation_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_redirected_to(/racecar\.jpg\?.*disposition=inline/)

    image = read_image(@blob.variant(resize: "100x100"))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "showing variant with invalid signed blob ID" do
    get rails_blob_variation_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_response :not_found
  end
end
