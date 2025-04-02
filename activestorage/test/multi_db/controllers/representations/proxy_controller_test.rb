# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"
require "minitest/mock"

module ActiveStorage::Representations
  class ProxyControllerWithVariantsTest < ActionDispatch::IntegrationTest
    setup do
      @main_blob = create_main_file_blob filename: "racecar.jpg"
      @animals_blob = create_animals_file_blob filename: "racecar.jpg"
      @transformations = { resize_to_limit: [100, 100] }
    end

    test "showing main variant attachment" do
      get rails_main_blob_representation_proxy_url(
        disposition: :attachment,
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :ok
      assert_match(/^attachment/, response.headers["Content-Disposition"])
      assert_equal @main_blob.variant(@transformations).download, response.body
    end

    test "showing animals variant attachment" do
      get rails_animals_blob_representation_proxy_url(
        disposition: :attachment,
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :ok
      assert_match(/^attachment/, response.headers["Content-Disposition"])
      assert_equal @animals_blob.variant(@transformations).download, response.body
    end

    test "showing main variant inline" do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :ok
      assert_match(/^inline/, response.headers["Content-Disposition"])
      assert_equal @main_blob.variant(@transformations).download, response.body
    end

    test "showing animals variant inline" do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :ok
      assert_match(/^inline/, response.headers["Content-Disposition"])
      assert_equal @animals_blob.variant(@transformations).download, response.body
    end

    test "showing untracked main variant" do
      without_variant_tracking do
        get rails_main_blob_representation_proxy_url(
          disposition: :attachment,
          filename: @main_blob.filename,
          signed_blob_id: @main_blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(@transformations))

        assert_response :ok
        assert_match(/^attachment/, response.headers["Content-Disposition"])
        assert_equal @main_blob.variant(@transformations).download, response.body
      end
    end

    test "showing untracked animals variant" do
      without_variant_tracking do
        get rails_animals_blob_representation_proxy_url(
          disposition: :attachment,
          filename: @animals_blob.filename,
          signed_blob_id: @animals_blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(@transformations))

        assert_response :ok
        assert_match(/^attachment/, response.headers["Content-Disposition"])
        assert_equal @animals_blob.variant(@transformations).download, response.body
      end
    end

    test "showing main variant with invalid signed blob ID" do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: "invalid",
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :not_found
    end

    test "showing animals variant with invalid signed blob ID" do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: "invalid",
        variation_key: ActiveStorage::Variation.encode(@transformations))

      assert_response :not_found
    end

    test "showing main variant with invalid variation key" do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: "invalid")

      assert_response :not_found
    end

    test "showing animals variant with invalid variation key" do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: "invalid")

      assert_response :not_found
    end

    test "sessions are disabled for main" do
      get rails_main_blob_representation_proxy_url(
        disposition: :attachment,
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
      assert request.session_options[:skip],
        "Expected request.session_options[:skip] to be true"
    end

    test "sessions are disabled for animals" do
      get rails_animals_blob_representation_proxy_url(
        disposition: :attachment,
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
      assert request.session_options[:skip],
        "Expected request.session_options[:skip] to be true"
    end
  end
end

class ActiveStorage::Representations::ProxyControllerWithVariantsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @transformations = { resize_to_limit: [100, 100] }
    @main_blob = create_main_file_blob filename: "racecar.jpg"
    @main_blob.variant(@transformations).processed

    @animals_blob = create_animals_file_blob filename: "racecar.jpg"
    @animals_blob.variant(@transformations).processed
  end

  test "showing existing main variant record" do
    with_strict_loading_by_default do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @main_blob.variant(@transformations).download, response.body
  end

  test "showing existing animals variant record" do
    with_strict_loading_by_default do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @animals_blob.variant(@transformations).download, response.body
  end

  test "invalidates cache and returns a 404 if the file is not found on download for main" do
    # This mock requires a pre-processed variant as processing the variant will call to download
    mock_download = lambda do |_|
      raise ActiveStorage::FileNotFoundError.new "File still uploading!"
    end

    @main_blob.service.stub(:download, mock_download) do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end
    assert_response :not_found
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  test "invalidates cache and returns a 404 if the file is not found on download for animals" do
    # This mock requires a pre-processed variant as processing the variant will call to download
    mock_download = lambda do |_|
      raise ActiveStorage::FileNotFoundError.new "File still uploading!"
    end

    @animals_blob.service.stub(:download, mock_download) do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end
    assert_response :not_found
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  test "invalidates cache and returns a 500 if the an error is raised on download for main" do
    # This mock requires a pre-processed variant as processing the variant will call to download
    mock_download = lambda do |_|
      raise StandardError.new "Something is not cool!"
    end

    @main_blob.service.stub(:download, mock_download) do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end
    assert_response :internal_server_error
    assert_equal "no-cache", response.headers["Cache-Control"]
  end

  test "invalidates cache and returns a 500 if the an error is raised on download for animals" do
    # This mock requires a pre-processed variant as processing the variant will call to download
    mock_download = lambda do |_|
      raise StandardError.new "Something is not cool!"
    end

    @animals_blob.service.stub(:download, mock_download) do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end
    assert_response :internal_server_error
    assert_equal "no-cache", response.headers["Cache-Control"]
  end
end

class ActiveStorage::Representations::ProxyControllerWithPreviewsTest < ActionDispatch::IntegrationTest
  setup do
    @main_blob = create_main_file_blob filename: "report.pdf", content_type: "application/pdf"
    @animals_blob = create_animals_file_blob filename: "report.pdf", content_type: "application/pdf"
    @transformations = { resize_to_limit: [100, 100] }
  end

  test "showing main preview inline" do
    get rails_main_blob_representation_proxy_url(
      filename: @main_blob.filename,
      signed_blob_id: @main_blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @main_blob.preview(@transformations).download, response.body
  end

  test "showing animals preview inline" do
    get rails_animals_blob_representation_proxy_url(
      filename: @animals_blob.filename,
      signed_blob_id: @animals_blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @animals_blob.preview(@transformations).download, response.body
  end

  test "showing main preview with invalid signed blob ID" do
    get rails_main_blob_representation_proxy_url(
      filename: @main_blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :not_found
  end

  test "showing animals preview with invalid signed blob ID" do
    get rails_animals_blob_representation_proxy_url(
      filename: @animals_blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(@transformations))

    assert_response :not_found
  end

  test "showing main preview with invalid variation key" do
    get rails_main_blob_representation_proxy_url(
      filename: @main_blob.filename,
      signed_blob_id: @main_blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end

  test "showing animals preview with invalid variation key" do
    get rails_animals_blob_representation_proxy_url(
      filename: @animals_blob.filename,
      signed_blob_id: @animals_blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end
end

class ActiveStorage::Representations::ProxyControllerWithPreviewsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @transformations = { resize_to_limit: [100, 100] }

    @main_blob = create_main_file_blob filename: "report.pdf", content_type: "application/pdf"
    @main_blob.preview(@transformations).processed

    @animals_blob = create_animals_file_blob filename: "report.pdf", content_type: "application/pdf"
    @animals_blob.preview(@transformations).processed
  end

  test "showing existing main preview record" do
    with_strict_loading_by_default do
      get rails_main_blob_representation_proxy_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @main_blob.preview(@transformations).download, response.body
  end

  test "showing existing animals preview record" do
    with_strict_loading_by_default do
      get rails_animals_blob_representation_proxy_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(@transformations))
    end

    assert_response :ok
    assert_match(/^inline/, response.headers["Content-Disposition"])
    assert_equal @animals_blob.preview(@transformations).download, response.body
  end
end
