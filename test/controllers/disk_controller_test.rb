require "test_helper"
require "database/setup"

require "active_storage/disk_controller"

class ActiveStorage::DiskControllerTest < ActionController::TestCase
  setup do
    @routes = Routes
    @controller = ActiveStorage::DiskController.new
  end

  test "showing blob inline" do
    blob = create_blob

    get :show, params: { filename: blob.filename, encoded_key: ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key) }
    assert_equal "inline; filename=\"#{blob.filename}\"", @response.headers["Content-Disposition"]
    assert_equal "text/plain", @response.headers["Content-Type"]
  end

  test "showing blob as attachment" do
    blob = create_blob

    get :show, params: { filename: blob.filename, encoded_key: ActiveStorage.verifier.generate(blob.key, expires_in: 5.minutes, purpose: :blob_key), disposition: :attachment }
    assert_equal "attachment; filename=\"#{blob.filename}\"", @response.headers["Content-Disposition"]
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

    @request.content_type = "text/plain"

    put :update, body: data, params: { encoded_token: token }
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

    @request.content_type = "text/plain"

    put :update, body: data, params: { encoded_token: token }
    assert_response :unprocessable_entity
    assert_not blob.service.exist?(blob.key)
  end
end
