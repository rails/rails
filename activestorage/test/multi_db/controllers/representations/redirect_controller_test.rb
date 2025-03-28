# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

module ActiveStorage::Representations
  class RedirectControllerWithVariantsTest < ActionDispatch::IntegrationTest
    setup do
      @main_blob = create_main_file_blob filename: "racecar.jpg"
      @animals_blob = create_animals_file_blob filename: "racecar.jpg"
    end

    test "showing main variant inline" do
      get rails_main_blob_representation_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

      assert_redirected_to(/racecar\.jpg/)
      follow_redirect!
      assert_match(/^inline/, response.headers["Content-Disposition"])

      image = read_image(@main_blob.variant(resize_to_limit: [100, 100]))
      assert_equal 100, image.width
      assert_equal 67, image.height
    end

    test "showing animals variant inline" do
      get rails_animals_blob_representation_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

      assert_redirected_to(/racecar\.jpg/)
      follow_redirect!
      assert_match(/^inline/, response.headers["Content-Disposition"])

      image = read_image(@animals_blob.variant(resize_to_limit: [100, 100]))
      assert_equal 100, image.width
      assert_equal 67, image.height
    end

    test "showing main variant with invalid signed blob ID" do
      get rails_main_blob_representation_url(
        filename: @main_blob.filename,
        signed_blob_id: "invalid",
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

      assert_response :not_found
    end

    test "showing animals variant with invalid signed blob ID" do
      get rails_animals_blob_representation_url(
        filename: @animals_blob.filename,
        signed_blob_id: "invalid",
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

      assert_response :not_found
    end

    test "showing main variant with invalid variation key" do
      get rails_main_blob_representation_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: "invalid")

      assert_response :not_found
    end

    test "showing animals variant with invalid variation key" do
      get rails_animals_blob_representation_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: "invalid")

      assert_response :not_found
    end
  end
end

class ActiveStorage::Representations::RedirectControllerWithVariantsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @main_blob = create_main_file_blob filename: "racecar.jpg"
    @main_blob.variant(resize_to_limit: [100, 100]).processed

    @animals_blob = create_animals_file_blob filename: "racecar.jpg"
    @animals_blob.variant(resize_to_limit: [100, 100]).processed
  end

  test "showing existing main variant record inline" do
    with_strict_loading_by_default do
      get rails_main_blob_representation_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end

    assert_redirected_to(/racecar\.jpg/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    @main_blob.reload # became free of strict_loading?
    image = read_image(@main_blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "showing existing animals variant record inline" do
    with_strict_loading_by_default do
      get rails_animals_blob_representation_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end

    assert_redirected_to(/racecar\.jpg/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    @animals_blob.reload # became free of strict_loading?
    image = read_image(@animals_blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end
end

class ActiveStorage::Representations::RedirectControllerWithPreviewsTest < ActionDispatch::IntegrationTest
  setup do
    @main_blob = create_main_file_blob filename: "report.pdf", content_type: "application/pdf"

    @animals_blob = create_animals_file_blob filename: "report.pdf", content_type: "application/pdf"
  end

  test "showing main preview inline" do
    get rails_main_blob_representation_url(
      filename: @main_blob.filename,
      signed_blob_id: @main_blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_predicate @main_blob.preview_image, :attached?
    assert_redirected_to(/report\.png/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    image = read_image(@main_blob.preview_image.variant(resize_to_limit: [100, 100]))
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "showing animals preview inline" do
    get rails_animals_blob_representation_url(
      filename: @animals_blob.filename,
      signed_blob_id: @animals_blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_predicate @animals_blob.preview_image, :attached?
    assert_redirected_to(/report\.png/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    image = read_image(@animals_blob.preview_image.variant(resize_to_limit: [100, 100]))
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "showing main preview with invalid signed blob ID" do
    get rails_main_blob_representation_url(
      filename: @main_blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :not_found
  end

  test "showing animals preview with invalid signed blob ID" do
    get rails_animals_blob_representation_url(
      filename: @animals_blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :not_found
  end

  test "showing main preview with invalid variation key" do
    get rails_main_blob_representation_url(
      filename: @main_blob.filename,
      signed_blob_id: @main_blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end

  test "showing animals preview with invalid variation key" do
    get rails_animals_blob_representation_url(
      filename: @animals_blob.filename,
      signed_blob_id: @animals_blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end
end

class ActiveStorage::Representations::RedirectControllerWithPreviewsWithStrictLoadingTest < ActionDispatch::IntegrationTest
  setup do
    @main_blob = create_main_file_blob filename: "report.pdf", content_type: "application/pdf"
    @main_blob.preview(resize_to_limit: [100, 100]).processed.send(:variant).processed

    @animals_blob = create_animals_file_blob filename: "report.pdf", content_type: "application/pdf"
    @animals_blob.preview(resize_to_limit: [100, 100]).processed.send(:variant).processed
  end

  test "showing existing main preview record inline" do
    with_strict_loading_by_default do
      get rails_main_blob_representation_url(
        filename: @main_blob.filename,
        signed_blob_id: @main_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end

    assert_predicate @main_blob.preview_image, :attached?
    assert_redirected_to(/report\.png/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    @main_blob.reload # became free of strict_loading?
    image = read_image(@main_blob.preview_image.variant(resize_to_limit: [100, 100]))
    assert_equal 77, image.width
    assert_equal 100, image.height
  end

  test "showing existing animals preview record inline" do
    with_strict_loading_by_default do
      get rails_animals_blob_representation_url(
        filename: @animals_blob.filename,
        signed_blob_id: @animals_blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end

    assert_predicate @animals_blob.preview_image, :attached?
    assert_redirected_to(/report\.png/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    @animals_blob.reload # became free of strict_loading?
    image = read_image(@animals_blob.preview_image.variant(resize_to_limit: [100, 100]))
    assert_equal 77, image.width
    assert_equal 100, image.height
  end
end

class ActiveStorage::Representations::RedirectControllerWithOpenRedirectTest < ActionDispatch::IntegrationTest
  if SERVICE_CONFIGURATIONS[:s3]
    test "showing existing variant stored in s3" do
      with_raise_on_open_redirects(:s3) do
        blob = create_file_blob filename: "racecar.jpg", service_name: :s3

        get rails_blob_representation_url(
          filename: blob.filename,
          signed_blob_id: blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

        assert_redirected_to(/racecar\.jpg/)
      end
    end
  end

  if SERVICE_CONFIGURATIONS[:azure]
    test "showing existing variant stored in azure" do
      with_raise_on_open_redirects(:azure) do
        blob = create_file_blob filename: "racecar.jpg", service_name: :azure

        get rails_blob_representation_url(
          filename: blob.filename,
          signed_blob_id: blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

        assert_redirected_to(/racecar\.jpg/)
      end
    end
  end

  if SERVICE_CONFIGURATIONS[:gcs]
    test "showing existing variant stored in gcs" do
      with_raise_on_open_redirects(:gcs) do
        blob = create_file_blob filename: "racecar.jpg", service_name: :gcs

        get rails_blob_representation_url(
          filename: blob.filename,
          signed_blob_id: blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

        assert_redirected_to(/racecar\.jpg/)
      end
    end
  end
end
