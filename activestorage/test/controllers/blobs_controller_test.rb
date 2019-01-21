# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::BlobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "showing blob with invalid signed ID" do
    get rails_service_blob_url("invalid", "racecar.jpg")
    assert_response :not_found
  end

  test "showing blob utilizes browser caching" do
    get rails_blob_url(@blob)

    assert_redirected_to(/racecar\.jpg/)
    assert_equal "max-age=300, private", @response.headers["Cache-Control"]
  end
end

if SERVICE_CONFIGURATIONS[:s3] && SERVICE_CONFIGURATIONS[:s3][:access_key_id].present?
  class ActiveStorage::S3BlobsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "allow redirection to the different host" do
      blob = create_file_blob filename: "racecar.jpg"

      assert_nothing_raised { get rails_blob_url(blob) }
      assert_response :redirect
      assert_no_match @request.host, @response.headers["Location"]
    ensure
      blob.purge
    end
  end
else
  puts "Skipping S3 redirection tests because no S3 configuration was supplied"
end
