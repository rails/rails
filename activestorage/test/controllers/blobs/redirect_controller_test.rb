# frozen_string_literal: true

require "test_helper"
require "database/setup"

class ActiveStorage::Blobs::RedirectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
  end

  test "invalid signed ID" do
    get rails_service_blob_url("invalid", "racecar.jpg")
    assert_response :not_found
  end

  test "HTTP caching" do
    get rails_storage_redirect_url(@blob)
    assert_redirected_to(/racecar\.jpg/)
    assert_equal "max-age=300, private", response.headers["Cache-Control"]
  end

  test "signed ID within expiration date" do
    get rails_storage_redirect_url(@blob, expires_in: 1.minute)
    assert_redirected_to(/racecar\.jpg/)
  end

  test "Expired signed ID" do
    url = rails_storage_redirect_url(@blob, expires_in: 1.minute)
    travel 2.minutes
    get url
    assert_response :not_found
  end
end

class ActiveStorage::Blobs::ExpiringRedirectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @blob = create_file_blob filename: "racecar.jpg"
    @old_urls_expire_in = ActiveStorage.urls_expire_in
    ActiveStorage.urls_expire_in = 1.minutes
  end

  teardown do
    ActiveStorage.urls_expire_in = @old_urls_expire_in
  end

  test "signed ID within expiration date" do
    get rails_storage_redirect_url(@blob)
    assert_redirected_to(/racecar\.jpg/)
  end

  test "Expired signed ID" do
    url = rails_storage_redirect_url(@blob)
    travel 2.minutes
    get url
    assert_response :not_found
  end
end
