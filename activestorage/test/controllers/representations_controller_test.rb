# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::RepresentationsControllerWithVariantsTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "showing variant inline" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_redirected_to(/racecar\.jpg\?.*disposition=inline/)

    image = read_image(@blob.variant(resize: "100x100"))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "showing variant with invalid signed blob ID" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_response :not_found
  end
end

class ActiveStorage::RepresentationsControllerWithPreviewsTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
  end

  test "showing preview inline" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_predicate @blob.preview_image, :attached?
    assert_redirected_to(/report\.png\?.*disposition=inline/)

    image = read_image(@blob.preview_image.variant(resize: "100x100"))
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "showing preview with invalid signed blob ID" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize: "100x100"))

    assert_response :not_found
  end
end

if SERVICE_CONFIGURATIONS[:s3] && SERVICE_CONFIGURATIONS[:s3][:access_key_id].present?
  class ActiveStorage::S3RepresentationsControllerWithVariantsTest < ActionDispatch::IntegrationTest
    setup do
      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "allow redirection to the different host" do
      blob = create_file_blob filename: "racecar.jpg"

      assert_nothing_raised do
        get rails_blob_representation_url(
          filename: blob.filename,
          signed_blob_id: blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(resize: "100x100"))
      end
      assert_response :redirect
      assert_no_match @request.host, @response.headers["Location"]
    ensure
      blob.purge
    end
  end
else
  puts "Skipping S3 redirection tests because no S3 configuration was supplied"
end
