# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::Blobs::ProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "invalid signed ID" do
    get rails_service_blob_proxy_url("invalid", "racecar.jpg")
    assert_response :not_found
  end

  test "HTTP caching" do
     get rails_storage_proxy_url(@blob)
     assert_response :success
     assert_equal "max-age=3155695200, public", response.headers["Cache-Control"]
   end
end
