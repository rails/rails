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

  test "signed ID within expiration duration" do
    get rails_storage_redirect_url(@blob, expires_in: 1.minute)
    assert_redirected_to(/racecar\.jpg/)
  end

  test "Expired signed ID within expiration duration" do
    url = rails_storage_redirect_url(@blob, expires_in: 1.minute)
    travel 2.minutes
    get url
    assert_response :not_found
  end

  test "signed ID within expiration time" do
    get rails_storage_redirect_url(@blob, expires_at: 1.minute.from_now)
    assert_redirected_to(/racecar\.jpg/)
  end

  test "Expired signed ID within expiration time" do
    url = rails_storage_redirect_url(@blob, expires_at: 1.minute.from_now)
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

class ActiveStorage::Blobs::RedirectControllerWithOpenRedirectTest < ActionDispatch::IntegrationTest
  if SERVICE_CONFIGURATIONS[:s3]
    test "showing existing blob stored in s3" do
      with_raise_on_open_redirects(:s3) do
        blob = create_file_blob filename: "racecar.jpg", service_name: :s3

        get rails_storage_redirect_url(blob)
        assert_redirected_to(/racecar\.jpg/)
      end
    end
  end

  if SERVICE_CONFIGURATIONS[:azure]
    test "showing existing blob stored in azure" do
      with_raise_on_open_redirects(:azure) do
        blob = create_file_blob filename: "racecar.jpg", service_name: :azure

        get rails_storage_redirect_url(blob)
        assert_redirected_to(/racecar\.jpg/)
      end
    end
  end

  if SERVICE_CONFIGURATIONS[:gcs]
    test "showing existing blob stored in gcs" do
      with_raise_on_open_redirects(:gcs) do
        blob = create_file_blob filename: "racecar.jpg", service_name: :gcs

        get rails_storage_redirect_url(blob)
        assert_redirected_to(/racecar\.jpg/)
      end
    end
  end
end
