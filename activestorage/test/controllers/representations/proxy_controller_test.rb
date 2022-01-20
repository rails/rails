# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::Representations::ProxyControllerWithVariantsTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "showing variant attachment" do
    get rails_blob_representation_proxy_url(
      disposition: :attachment,
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :ok
    assert_match(/^attachment/, response.headers["Content-Disposition"])

    image = read_image(@blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "showing variant inline" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])

    image = read_image(@blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "showing variant with invalid signed blob ID" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :not_found
  end

  test "showing variant with invalid variation key" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end
end

class ActiveStorage::Representations::ProxyControllerWithVariantsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @blob.variant(resize_to_limit: [100, 100]).processed
  end

  test "showing existing variant record"  do
    with_strict_loading_by_default do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end
    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])

    @blob.reload # became free of strict_loading?
    image = read_image(@blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end
end

class ActiveStorage::Representations::ProxyControllerWithPreviewsTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
  end

  test "showing preview inline" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])

    assert_predicate @blob.preview_image, :attached?

    image = read_image(@blob.preview_image.variant(resize_to_limit: [100, 100]).processed)
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "showing preview with invalid signed blob ID" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :not_found
  end

  test "showing preview with invalid variation key" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end
end

class ActiveStorage::Representations::ProxyControllerWithPreviewsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
    @blob.preview(resize_to_limit: [100, 100]).processed
  end

  test "showing existing preview record" do
    with_strict_loading_by_default do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    @blob.reload # became free of strict_loading?
    assert_predicate @blob.preview_image, :attached?

    image = read_image(@blob.preview_image.variant(resize_to_limit: [100, 100]).processed)
    assert_equal 77, image.width
    assert_equal 100, image.height
  end
end
