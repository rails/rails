require "test_helper"
require "database/setup"

class ActiveStorage::DiskControllerTest < ActionDispatch::IntegrationTest
  test "showing blob inline" do
    blob = create_blob
    key  = ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key)

    get rails_disk_service_url(key, blob.filename, content_type: blob.content_type)
    assert_equal "inline; filename=\"#{blob.filename.base}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "showing blob as attachment" do
    blob = create_blob
    key  = ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key)

    get rails_disk_service_url(key, blob.filename, content_type: blob.content_type, disposition: :attachment)
    assert_equal "attachment; filename=\"#{blob.filename.base}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "directly uploading blob with integrity" do
    data  = "Something else entirely!"
    blob  = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)
    token = encode_verified_token_for blob

    put update_rails_disk_service_url(token), params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :no_content
    assert_equal data, blob.download
  end

  test "directly uploading blob without integrity" do
    data  = "Something else entirely!"
    blob  = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest("bad data")
    token = encode_verified_token_for blob

    put update_rails_disk_service_url(token), params: data
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with mismatched content type" do
    data  = "Something else entirely!"
    blob  = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)
    token = encode_verified_token_for blob

    put update_rails_disk_service_url(token), params: data, headers: { "Content-Type" => "application/octet-stream" }
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  test "directly uploading blob with mismatched content length" do
    data  = "Something else entirely!"
    blob  = create_blob_before_direct_upload byte_size: data.size - 1, checksum: Digest::MD5.base64digest(data)
    token = encode_verified_token_for blob

    put update_rails_disk_service_url(token), params: data, headers: { "Content-Type" => "text/plain" }
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end

  private
    def encode_verified_token_for(blob)
      ActiveStorage.verifier.generate(
        {
          key: blob.key,
          content_length: blob.byte_size,
          content_type: blob.content_type,
          checksum: blob.checksum
        },
        expires_in: 5.minutes,
        purpose: :blob_token
      )
    end
end
