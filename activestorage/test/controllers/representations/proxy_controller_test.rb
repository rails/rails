# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::Representations::ProxyControllerWithVariantsTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @transformations = { resize_to_limit: [100, 100] }
  end

  test "showing variant attachment" do
    get rails_blob_representation_proxy_url(
      disposition: :attachment,
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :ok
    assert_match(/^attachment/, response.headers["Content-Disposition"])
    assert_equal @blob.variant(@transformations).download, response.body
  end

  test "showing variant inline" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @blob.variant(@transformations).download, response.body
  end

  test "showing untracked variant" do
    without_variant_tracking do
      get rails_blob_representation_proxy_url(
        disposition: :attachment,
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :ok
      assert_match(/^attachment/, response.headers["Content-Disposition"])
      assert_equal @blob.variant(@transformations).download, response.body
    end
  end

  test "showing variant with invalid signed blob ID" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :not_found
  end

  test "showing variant with invalid variation key" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end

  test "sessions are disabled" do
    get rails_blob_representation_proxy_url(
      disposition: :attachment,
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))
    assert request.session_options[:skip],
      "Expected request.session_options[:skip] to be true"
  end
end

class ActiveStorage::Representations::ProxyControllerWithVariantsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @transformations = { resize_to_limit: [100, 100] }
    @blob.variant(@transformations).processed
  end

  test "showing existing variant record"  do
    with_strict_loading_by_default do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @blob.variant(@transformations).download, response.body
  end


  test "invalidates cache and returns a 404 if the file is not found on download" do
    # This mock requires a pre-processed variant as processing the variant will call to download
    mock_download = lambda do |_|
      raise ActiveStorage::FileNotFoundError.new "File still uploading!"
    end

    @blob.service.stub(:download, mock_download) do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end
    assert_response :not_found
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  test "invalidates cache and returns a 500 if the an error is raised on download" do
    # This mock requires a pre-processed variant as processing the variant will call to download
    mock_download = lambda do |_|
      raise StandardError.new "Something is not cool!"
    end

    @blob.service.stub(:download, mock_download) do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end
    assert_response :internal_server_error
    assert_equal "no-cache", response.headers["Cache-Control"]
  end
end

class ActiveStorage::Representations::ProxyControllerWithPreviewsTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
    @transformations = { resize_to_limit: [100, 100] }
  end

  test "showing preview inline" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @blob.preview(@transformations).download, response.body
  end

  test "showing preview with invalid signed blob ID" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(@transformations))

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
    @transformations = { resize_to_limit: [100, 100] }
    @blob.preview(@transformations).processed
  end

  test "showing existing preview record" do
    with_strict_loading_by_default do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @blob.preview(@transformations).download, response.body
  end
end
