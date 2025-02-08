# frozen_string_literal: true

require "test_helper"

require "active_storage/previewer/poppler_pdf_previewer"

class RedirectControllerTestCase < ActionDispatch::IntegrationTest
  setup do
    @was_inline_content_types = ActiveStorage.content_types_allowed_inline
    @was_web_content_types = ActiveStorage.web_image_content_types
    @was_variable_content_types = ActiveStorage.variable_content_types
    @was_variant_transformer = ActiveStorage.variant_transformer

    ActiveStorage.content_types_allowed_inline = %(image/png image/jpeg)
    ActiveStorage.web_image_content_types = %(image/png image/jpeg)
    ActiveStorage.variable_content_types = %(image/png image/jpeg)
    ActiveStorage.variant_transformer = ActiveStorage::Transformers::ImageMagick
  end

  teardown do
    ActiveStorage.content_types_allowed_inline = @was_inline_content_types
    ActiveStorage.web_image_content_types = @was_web_content_types
    ActiveStorage.variable_content_types = @was_variable_content_types
    ActiveStorage.variant_transformer = @was_variant_transformer
  end
end

class ActiveStorage::Representations::RedirectControllerWithVariantsTest < RedirectControllerTestCase
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "showing variant inline" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_redirected_to(/racecar\.jpg/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    image = read_image(@blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end

  test "showing variant with invalid signed blob ID" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :not_found
  end

  test "showing variant with invalid variation key" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: @blob.signed_id,
      variation_key: "invalid")

    assert_response :not_found
  end
end

class ActiveStorage::Representations::RedirectControllerWithVariantsWithStrictLoadingTest < RedirectControllerTestCase
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @blob.variant(resize_to_limit: [100, 100]).processed
  end

  test "showing existing variant record inline" do
    with_strict_loading_by_default do
      get rails_blob_representation_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
    end

    assert_redirected_to(/racecar\.jpg/)
    follow_redirect!
    assert_match(/^inline/, response.headers["Content-Disposition"])

    @blob.reload # became free of strict_loading?
    image = read_image(@blob.variant(resize_to_limit: [100, 100]))
    assert_equal 100, image.width
    assert_equal 67, image.height
  end
end

class ActiveStorage::Representations::RedirectControllerWithPreviewsTest < RedirectControllerTestCase
  setup do
    @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
  end

  test "showing preview inline" do
    preview_with("PopplerPDFPreviewer") do
      get rails_blob_representation_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

      assert_predicate @blob.preview_image, :attached?
      assert_redirected_to(/report\.png/)
      follow_redirect!
      assert_match(/^inline/, response.headers["Content-Disposition"])

      image = read_image(@blob.preview_image.variant(resize_to_limit: [100, 100]))
      assert_equal 77, image.width
      assert_equal 100, image.height
    end
  end

  test "showing preview with invalid signed blob ID" do
    get rails_blob_representation_url(
      filename: @blob.filename,
      signed_blob_id: "invalid",
      variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

    assert_response :not_found
  end

  test "showing preview with invalid variation key" do
    preview_with("PopplerPDFPreviewer") do
      get rails_blob_representation_url(
        filename: @blob.filename,
        signed_blob_id: @blob.signed_id,
        variation_key: "invalid")

      assert_response :not_found
    end
  end
end

class ActiveStorage::Representations::RedirectControllerWithPreviewsWithStrictLoadingTest < RedirectControllerTestCase
  setup do
    preview_with("PopplerPDFPreviewer") do
      @blob = create_file_blob filename: "report.pdf", content_type: "application/pdf"
      @blob.preview(resize_to_limit: [100, 100]).processed.send(:variant).processed
    end
  end

  test "showing existing preview record inline" do
    preview_with("PopplerPDFPreviewer") do
      with_strict_loading_by_default do
        get rails_blob_representation_url(
          filename: @blob.filename,
          signed_blob_id: @blob.signed_id,
          variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))
      end

      assert_predicate @blob.preview_image, :attached?
      assert_redirected_to(/report\.png/)
      follow_redirect!
      assert_match(/^inline/, response.headers["Content-Disposition"])

      @blob.reload # became free of strict_loading?
      image = read_image(@blob.preview_image.variant(resize_to_limit: [100, 100]))
      assert_equal 77, image.width
      assert_equal 100, image.height
    end
  end
end

class ActiveStorage::Representations::RedirectControllerWithOpenRedirectTest < RedirectControllerTestCase
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
        preview_with("PopplerPDFPreviewer") do
          blob = create_file_blob filename: "racecar.jpg", service_name: :azure

          get rails_blob_representation_url(
            filename: blob.filename,
            signed_blob_id: blob.signed_id,
            variation_key: ActiveStorage::Variation.encode(resize_to_limit: [100, 100]))

          assert_redirected_to(/racecar\.jpg/)
        end
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
