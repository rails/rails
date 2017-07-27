require "test_helper"
require "database/setup"

class ActiveStorage::DiskControllerTest < ActionDispatch::IntegrationTest
  test "showing blob inline" do
    blob = create_blob

    get rails_disk_service_url(
      filename: "hello.txt",
      content_type: blob.content_type,
      encoded_key: ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key)
    )

    assert_equal "inline; filename=\"#{blob.filename.base}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "sending blob as attachment" do
    blob = create_blob

    get rails_disk_service_url(
      filename: blob.filename,
      content_type: blob.content_type,
      encoded_key: ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key),
      disposition: :attachment
    )

    assert_equal "attachment; filename=\"#{blob.filename.base}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "directly uploading blob with integrity" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)
    token = ActiveStorage.verifier.generate(
      {
        key: blob.key,
        content_length: data.size,
        content_type: "text/plain",
        checksum: Digest::MD5.base64digest(data)
      },
      expires_in: 5.minutes,
      purpose: :blob_token
    )

    put update_rails_disk_service_url(encoded_token: token), params: data, headers: { "Content-Type" => "text/plain" }

    assert_response :no_content
    assert_equal data, blob.download
  end

  test "directly uploading blob without integrity" do
    data = "Something else entirely!"
    blob = create_blob_before_direct_upload byte_size: data.size, checksum: Digest::MD5.base64digest(data)

    token = ActiveStorage.verifier.generate(
      {
        key: blob.key,
        content_length: data.size,
        content_type: "text/plain",
        checksum: Digest::MD5.base64digest("bad data")
      },
      expires_in: 5.minutes,
      purpose: :blob_token
    )

    put update_rails_disk_service_url(encoded_token: token), params: { body: data }

    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end
end
