# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::DiskControllerTest < ActionDispatch::IntegrationTest
  test "showing blob inline" do
    blob = create_blob
    get blob.service_url
    assert_response :ok
    assert_equal "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
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

  test "showing blob range inline" do
    blob = create_blob
    get blob.service_url, headers: { "Range" => "bytes=5-9" }
    assert_response :partial_content
    assert_equal "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", response.headers["Content-Disposition"]
    assert_equal "text/plain", response.headers["Content-Type"]
    assert_equal " worl", response.body
  end

  test "showing blob that does not exist" do
    blob = create_blob
    blob.delete

    get blob.service_url
    assert_response :not_found
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
end
