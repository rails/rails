# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class ProxyControllerTestCase < ActionDispatch::IntegrationTest
  setup do
    @was_variable_content_types = ActiveStorage.variable_content_types
    @was_variant_transformer = ActiveStorage.variant_transformer
    ActiveStorage.variable_content_types = %w(image/png image/jpeg)
    ActiveStorage.variant_transformer = ActiveStorage::Transformers::ImageMagick
  end

  teardown do
    ActiveStorage.variable_content_types = @was_variable_content_types
    ActiveStorage.variant_transformer = @was_variant_transformer
  end
end

class ActiveStorage::Representations::ProxyControllerWithVariantsTest < ProxyControllerTestCase
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
    with_inline_content_types(%w(image/png)) do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @blob.variant(@transformations).download, response.body
  end

  test "showing untracked variant" do
    get rails_blob_representation_proxy_url(
      disposition: :attachment,
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :ok
    assert_match(/^attachment/, response.headers["Content-Disposition"])
    assert_equal @blob.variant(@transformations).download, response.body
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

class ActiveStorage::Representations::ProxyControllerWithVariantsWithStrictLoadingTest < ProxyControllerTestCase
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @transformations = { resize_to_limit: [100, 100] }
    @blob.variant(@transformations).processed
  end

  test "showing existing variant record"  do
    with_inline_content_types(%w(image/png)) do
      with_strict_loading_by_default do
        get rails_blob_representation_proxy_url(
          filename: @blob.filename,
          signed_blob_id: @blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(@transformations))
      end
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

class ActiveStorage::Representations::ProxyControllerWithPreviewsTest < ProxyControllerTestCase
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
    @transformations = { resize_to_limit: [100, 100] }
  end

  test "showing preview inline" do
    preview_with("PopplerPDFPreviewer") do
      with_inline_content_types(%w(image/png)) do
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

  test "showing preview with invalid signed blob ID" do
    get rails_blob_representation_proxy_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :not_found
  end

  test "showing preview with invalid variation key" do
    preview_with("PopplerPDFPreviewer") do
      get rails_blob_representation_proxy_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: "invalid")

      assert_response :not_found
    end
  end
end

class ActiveStorage::Representations::ProxyControllerWithPreviewsWithStrictLoadingTest < ProxyControllerTestCase
  setup do
    preview_with("PopplerPDFPreviewer") do
      @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
      @transformations = { resize_to_limit: [100, 100] }
      @blob.preview(@transformations).processed
    end
  end

  test "showing existing preview record" do
    preview_with("PopplerPDFPreviewer") do
      with_inline_content_types(%w(image/png)) do
        with_strict_loading_by_default do
          get rails_blob_representation_proxy_url(
            filename: @blob.filename,
            signed_blob_id: @blob.signed_id,
            variation_key: ActiveStorage::Variation.encode(@transformations))
        end
      end

      assert_response :ok
      assert_match(/^inline/, response.headers["Content-Disposition"])
      assert_equal @blob.preview(@transformations).download, response.body
    end
  end
end
