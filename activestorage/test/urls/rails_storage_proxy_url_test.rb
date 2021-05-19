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
    variant = @blob.variant(resize: "100x100")
    assert_includes rails_blob_path(variant, only_path: true), "/rails/active_storage/representations/proxy/"
  end

  test "rails_representation_path generates proxy path" do
    variant = @blob.variant(resize: "100x100")
    assert_includes rails_representation_path(variant, only_path: true), "/rails/active_storage/representations/proxy/"
  end

  test "rails_storage_proxy_url with cdn_host adds the host to the url" do
    with_cdn "https://cdn.example.com" do
      assert_includes rails_storage_proxy_url(@blob), "https://cdn.example.com/rails/active_storage/blobs/proxy/"
    end
  end

  test "rails_storage_proxy_url with cdn_host overrides the default application host" do
    original_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options.merge!(protocol: "http", host: "test.example.com", port: 3001)
    with_cdn "https://cdn.example.com" do
      assert_includes rails_storage_proxy_url(@blob), "https://cdn.example.com/rails/active_storage/blobs/proxy/"
    end
  ensure
    Rails.application.routes.default_url_options = original_url_options
  end

  test "rails_storage_proxy_url with cdn_host and port adds the host to the url" do
    with_cdn "https://cdn.example.com:7777" do
      assert_includes rails_storage_proxy_url(@blob), "https://cdn.example.com:7777/rails/active_storage/blobs/proxy/"
    end
  end

  test "rails_storage_proxy_url with cdn_host without protocol adds the host to the url" do
    with_cdn "cdn.example.com" do
      assert_includes rails_storage_proxy_url(@blob), "http://cdn.example.com/rails/active_storage/blobs/proxy/"
    end
  end

  test "rails_storage_proxy_url without cdn_host uses the default application host" do
    original_url_options = Rails.application.routes.default_url_options.dup
    Rails.application.routes.default_url_options.merge!(protocol: "http", host: "test.example.com", port: 3001)
    with_cdn nil do
      assert_includes rails_storage_proxy_url(@blob), "http://test.example.com:3001/rails/active_storage/blobs/proxy/"
    end
  ensure
    Rails.application.routes.default_url_options = original_url_options
  end

  private
    def with_cdn(cdn_host)
      ActiveStorage.cdn_host, previous = cdn_host, ActiveStorage.cdn_host
      yield
    ensure
      ActiveStorage.cdn_host = previous
    end
end
