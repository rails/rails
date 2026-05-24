# frozen_string_literal: true

require "test_helper"
require "test_helpers/active_model_owner"

class ActiveStorage::CustomBackendServingTest < ActionDispatch::IntegrationTest
  include ActiveStorage::ActiveModelOwnerTestSupport

  test "redirects and proxies downloads from the configured backend" do
    blob = create_memory_blob(data: "custom backend")

    get rails_storage_redirect_url(blob)
    assert_response :redirect
    follow_redirect!
    assert_response :success
    assert_equal "custom backend", response.body

    get rails_storage_proxy_url(blob)
    assert_response :success
    assert_equal "custom backend", response.body
    assert_equal "text/plain", response.media_type
    assert_equal blob.byte_size.to_s, response.headers["Content-Length"]
  end

  test "proxy downloads support byte ranges with the custom backend" do
    blob = create_memory_blob(data: "custom backend")

    get rails_storage_proxy_url(blob), headers: { "Range" => "bytes=7-10" }

    assert_response :partial_content
    assert_equal "back", response.body
    assert_equal "bytes 7-10/14", response.headers["Content-Range"]
  end

  test "redirects and proxies reject invalid signatures and purposes" do
    blob = create_memory_blob
    tokens = ["invalid", blob.signed_id(purpose: :other)]

    [:rails_service_blob_url, :rails_service_blob_proxy_url].product(tokens).each do |route, token|
      get public_send(route, token, blob.filename)
      assert_response :not_found
    end
  end

  test "redirects and proxies reject expired signed ids" do
    blob = create_memory_blob
    token = blob.signed_id(expires_in: 1.minute)

    travel 2.minutes do
      [:rails_service_blob_url, :rails_service_blob_proxy_url].each do |route|
        get public_send(route, token, blob.filename)
        assert_response :not_found
      end
    end
  end

  test "redirects and proxies return not found for deleted custom blobs" do
    blob = create_memory_blob
    token = blob.signed_id
    blob.purge

    [:rails_service_blob_url, :rails_service_blob_proxy_url].each do |route|
      get public_send(route, token, blob.filename)
      assert_response :not_found
    end
  end

  test "unsafe content is downloaded as binary through redirects and proxies" do
    ["text/html", "image/svg+xml"].each do |content_type|
      blob = create_memory_blob(content_type: content_type, data: "<script>alert(1)</script>")

      get rails_storage_redirect_url(blob, disposition: :inline)
      assert_response :redirect
      follow_redirect!
      assert_response :success
      assert_equal "application/octet-stream", response.media_type
      assert_match(/^attachment; /, response.headers["Content-Disposition"])

      get rails_storage_proxy_url(blob, disposition: :inline)
      assert_response :success
      assert_equal "application/octet-stream", response.media_type
      assert_match(/^attachment; /, response.headers["Content-Disposition"])
    end
  end

  test "disk direct uploads resolve the service through the custom blob class" do
    data = "uploaded through the custom backend"
    blob = ActiveStorage.blob_class.create_before_direct_upload!(
      filename: "custom.txt", content_type: "text/plain", byte_size: data.bytesize,
      checksum: ActiveStorage::Services.default.compute_checksum(StringIO.new(data))
    )

    put blob.service_url_for_direct_upload, params: data, headers: blob.service_headers_for_direct_upload

    assert_response :no_content
    assert_equal data, blob.download
    get rails_storage_proxy_url(blob)
    assert_response :success
    assert_equal data, response.body
  end

  test "disk direct uploads reject invalid service tokens and mismatched contents" do
    data = "custom backend"
    blob = ActiveStorage.blob_class.create_before_direct_upload!(
      filename: "custom.txt", content_type: "text/plain", byte_size: data.bytesize,
      checksum: ActiveStorage::Services.default.compute_checksum(StringIO.new(data))
    )

    put update_rails_disk_service_url(encoded_token: "invalid"), params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :not_found
    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/html" }
    assert_response ActionDispatch::Constants::UNPROCESSABLE_CONTENT
    assert_not blob.service.exist?(blob.key)
  end

  test "disk downloads and direct uploads report an unconfigured custom service registry" do
    blob = create_memory_blob
    download_url = blob.url
    upload_url = blob.service_url_for_direct_upload
    ActiveStorage::Services.registry = nil

    error = assert_raises(ActiveStorage::ConfigurationError) { get download_url }
    assert_match "services have not been configured", error.message
    error = assert_raises(ActiveStorage::ConfigurationError) do
      put upload_url, params: "Hello world!", headers: { "Content-Type" => "text/plain" }
    end
    assert_match "services have not been configured", error.message
  end

  test "analysis and purge jobs discard deleted custom blobs during deserialization" do
    blob = create_memory_blob
    [ActiveStorage::AnalyzeJob, ActiveStorage::PurgeJob].each { |job| job.perform_later(blob) }
    blob.purge
    discarded_jobs = []
    track_discards = ->(event) { discarded_jobs << event.payload.fetch(:job).class }

    ActiveSupport::Notifications.subscribed(track_discards, "discard.active_job") do
      perform_enqueued_jobs
    end

    assert_equal [ActiveStorage::AnalyzeJob, ActiveStorage::PurgeJob], discarded_jobs
    assert_empty enqueued_jobs
  end
end
