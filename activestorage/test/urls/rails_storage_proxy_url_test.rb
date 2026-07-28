# frozen_string_literal: true

require "test_helper"
require "database/setup"

class RailsStorageProxyUrlTest < ActiveSupport::TestCase
  include Rails.application.routes.url_helpers

  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @was_resolve_model_to_route, ActiveStorage.resolve_model_to_route = ActiveStorage.resolve_model_to_route, :rails_storage_proxy
  end

  teardown do
    ActiveStorage.resolve_model_to_route = @was_resolve_model_to_route
  end

  test "rails_storage_proxy_path generates proxy path" do
    assert_includes rails_storage_proxy_path(@blob, only_path: true), "/rails/active_storage/blobs/proxy/"
  end

  test "rails_storage_redirect_path generates redirect path" do
    assert_includes rails_storage_redirect_path(@blob, only_path: true), "/rails/active_storage/blobs/redirect/"
  end

  test "rails_blob_path generates proxy path" do
    assert_includes rails_blob_path(@blob, only_path: true), "/rails/active_storage/blobs/proxy/"
  end

  test "rails_blob_path with variant generates proxy path" do
    variant = @blob.variant(resize_to_limit: [100, 100])
    assert_includes rails_blob_path(variant, only_path: true), "/rails/active_storage/representations/proxy/"
  end

  test "rails_representation_path generates proxy path" do
    variant = @blob.variant(resize_to_limit: [100, 100])
    assert_includes rails_representation_path(variant, only_path: true), "/rails/active_storage/representations/proxy/"
  end

  test "rails_blob_path for a variant that changes the format uses the variant's extension" do
    variant = @blob.variant(resize_to_limit: [100, 100], format: :webp)
    assert rails_blob_path(variant, only_path: true).end_with?("/racecar.webp")
  end

  test "rails_blob_path for a variant that keeps the format uses the blob's extension" do
    variant = @blob.variant(resize_to_limit: [100, 100])
    assert rails_blob_path(variant, only_path: true).end_with?("/racecar.jpg")
  end

  test "rails_blob_path for a tracked variant that changes the format uses the variant's extension" do
    with_variant_tracking do
      variant = @blob.variant(resize_to_limit: [100, 100], format: :webp)
      assert_kind_of ActiveStorage::VariantWithRecord, variant
      assert rails_blob_path(variant, only_path: true).end_with?("/racecar.webp")
    end
  end

  test "rails_blob_path for an unprocessed preview falls back to the blob's filename" do
    blob = create_file_blob(filename: "report.pdf", content_type: "application/pdf")
    preview = ActiveStorage::Preview.new(blob, resize_to_limit: [100, 100])
    assert_not_predicate preview, :processed?

    assert rails_blob_path(preview, only_path: true).end_with?("/report.pdf")
  end

  test "rails_blob_path for a processed preview uses the preview image's extension" do
    preview = create_file_blob(filename: "report.pdf", content_type: "application/pdf").preview(resize_to_limit: [100, 100]).processed
    assert rails_blob_path(preview, only_path: true).end_with?("/report.png")
  end
end
