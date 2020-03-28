# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::BlobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_blob filename: "dummy.txt", data: "this is the payload"
  end

  test "showing blob with invalid signed ID" do
    get rails_service_blob_url("invalid", "dummy.txt")
    assert_response :not_found
  end

  test "showing blob utilizes browser caching" do
    get rails_blob_url(@blob)

    assert_redirected_to(/dummy\.txt/)
    assert_equal "max-age=300, private", @response.headers["Cache-Control"]
  end

  test "Can download blob before expiry" do
    time = Time.now
    url = rails_blob_url(@blob)

    travel_to time + ActiveStorage.urls_expire_in do
      get url
      follow_redirect!

      assert_response :ok
      assert_includes "this is the payload", response.body
    end
  end

  test "Cannot download blob after expiry" do
    time = Time.now
    url = rails_blob_url(@blob)

    travel_to time + ActiveStorage.urls_expire_in + 1.second do
      get url

      assert_response :not_found
    end
  end
end
