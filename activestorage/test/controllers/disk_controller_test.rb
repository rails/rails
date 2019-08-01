# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::DiskControllerTest < ActionDispatch::IntegrationTest
  test "showing blob inline" do
    blob = create_blob(filename: "hello.jpg", content_type: "image/jpg")

    get blob.service_url
    assert_response :ok
    assert_equal "inline; filename=\"hello.jpg\"; filename*=UTF-8''hello.jpg", response.headers["Content-Disposition"]
    assert_equal "image/jpg", response.headers["Content-Type"]
    assert_equal "Hello world!", response.body
  end

  test "showing blob as attachment" do
    blob = create_blob
    get blob.service_url(disposition: :attachment)
    assert_response :ok
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal "Hello world!", response.body
  end

  test "showing blob range" do
    blob = create_blob
    get blob.service_url, headers: { "Range" => "bytes=5-9" }
    assert_response :partial_content
    assert_equal "attachment; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal " worl", response.body
  end

  test "showing blob that does not exist" do
    blob = create_blob
    blob.delete

    get blob.service_url
  end

  test "showing blob with invalid key" do
    get rails_disk_service_url(encoded_key: "Invalid key", filename: "hello.txt")
    assert_response :not_found
  end

  test "showing blob from default service when multiple services" do
    previous_services, ActiveStorage::Blob.services = ActiveStorage::Blob.services, build_multiple_disk_services
    previous_default_service, ActiveStorage::Blob.default_service_name = ActiveStorage::Blob.default_service_name, "disk_one"

    blob = create_blob

    get blob.service_url
    assert_response :ok
    assert_equal "Hello world!", response.body
  ensure
    ActiveStorage::Blob.default_service_name = previous_default_service
    ActiveStorage::Blob.services = previous_services
  end

  test "showing blob from another service when multiple services" do
    previous_services, ActiveStorage::Blob.services = ActiveStorage::Blob.services, build_multiple_disk_services
    previous_default_service, ActiveStorage::Blob.default_service_name = ActiveStorage::Blob.default_service_name, "disk_one"

    blob = create_blob(service_name: "disk_two")

    get blob.service_url
    assert_response :ok
    assert_equal "Hello world!", response.body
  ensure
    ActiveStorage::Blob.default_service_name = previous_default_service
    ActiveStorage::Blob.services = previous_services
  end


  test "directly uploading blob with integrity" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)

    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :no_content
    assert_equal data, blob.download
  end

  test "directly uploading blob without integrity" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest("bad data")

    put blob.service_url_for_direct_upload, params: data
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with mismatched content type" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)

    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "application/octet-stream" }
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with different but equivalent content type" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload(
      byte_size: data.size, checksum: Digest::MD5.base64digest(data), content_type: "application/x-gzip")

    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "application/x-gzip" }
    assert_response :no_content
    assert_equal data, blob.download
  end

  test "directly uploading blob with mismatched content length" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size - 1, checksum: Digest::MD5.base64digest(data)

    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with invalid token" do
    put update_rails_disk_service_url(encoded_token: "invalid"),
      params: "Something else entirely!", headers: { "Content-Type" => "text/plain" }
    assert_response :not_found
  end

  test "directly uploading blob to default service when multiple services" do
    previous_services, ActiveStorage::Blob.services = ActiveStorage::Blob.services, build_multiple_disk_services
    previous_default_service, ActiveStorage::Blob.default_service_name = ActiveStorage::Blob.default_service_name, "disk_one"

    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)

    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :no_content
    assert_equal data, blob.download
    assert ActiveStorage::Blob.services["disk_one"].exist?(blob.key)
    assert_not ActiveStorage::Blob.services["disk_two"].exist?(blob.key)
  ensure
    ActiveStorage::Blob.default_service_name = previous_default_service
    ActiveStorage::Blob.services = previous_services
  end

  test "directly uploading blob to another service when multiple services" do
    previous_services, ActiveStorage::Blob.services = ActiveStorage::Blob.services, build_multiple_disk_services
    previous_default_service, ActiveStorage::Blob.default_service_name = ActiveStorage::Blob.default_service_name, "disk_one"

    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data), service_name: "disk_two"

    put blob.service_url_for_direct_upload, params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :no_content
    assert_equal data, blob.download
    assert_not ActiveStorage::Blob.services["disk_one"].exist?(blob.key)
    assert ActiveStorage::Blob.services["disk_two"].exist?(blob.key)
  ensure
    ActiveStorage::Blob.default_service_name = previous_default_service
    ActiveStorage::Blob.services = previous_services
  end

  private
    def build_multiple_disk_services
      {
        "disk_one" =>
          ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir("active_storage_tests_one")),
        "disk_two" =>
          ActiveStorage::Service::DiskService.new(root: Dir.mktmpdir("active_storage_tests_two"))
      }
    end
end
