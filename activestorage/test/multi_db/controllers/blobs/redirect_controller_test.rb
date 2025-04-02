# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"

module ActiveStorage::Blobs
  class RedirectControllerTest < ActionDispatch::IntegrationTest
    setup do
      @main_blob = create_main_file_blob filename: "racecar.jpg"
      @animals_blob = create_animals_file_blob filename: "racecar.jpg"
    end

    test "invalid signed ID for main" do
      get rails_service_main_blob_url("invalid", "racecar.jpg")
      assert_response :not_found
    end

    test "invalid signed ID for animals" do
      get rails_service_animals_blob_url("invalid", "racecar.jpg")
      assert_response :not_found
    end

    test "HTTP caching for main" do
      get rails_main_storage_redirect_url(@main_blob)
      assert_redirected_to(/racecar\.jpg/)
      assert_equal "max-age=300, private", response.headers["Cache-Control"]
    end

    test "HTTP caching for animals" do
      get rails_animals_storage_redirect_url(@animals_blob)
      assert_redirected_to(/racecar\.jpg/)
      assert_equal "max-age=300, private", response.headers["Cache-Control"]
    end

    test "signed ID within expiration duration for main" do
      get rails_main_storage_redirect_url(@main_blob, expires_in: 1.minute)
      assert_redirected_to(/racecar\.jpg/)
    end

    test "signed ID within expiration duration for animals" do
      get rails_animals_storage_redirect_url(@animals_blob, expires_in: 1.minute)
      assert_redirected_to(/racecar\.jpg/)
    end

    test "Expired signed ID within expiration duration for main" do
      url = rails_main_storage_redirect_url(@main_blob, expires_in: 1.minute)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "Expired signed ID within expiration duration for animals" do
      url = rails_animals_storage_redirect_url(@animals_blob, expires_in: 1.minute)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "signed ID within expiration time for main" do
      get rails_main_storage_redirect_url(@main_blob, expires_at: 1.minute.from_now)
      assert_redirected_to(/racecar\.jpg/)
    end

    test "signed ID within expiration time for animals" do
      get rails_animals_storage_redirect_url(@animals_blob, expires_at: 1.minute.from_now)
      assert_redirected_to(/racecar\.jpg/)
    end

    test "Expired signed ID within expiration time for main" do
      url = rails_main_storage_redirect_url(@main_blob, expires_at: 1.minute.from_now)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "Expired signed ID within expiration time for animals" do
      url = rails_animals_storage_redirect_url(@animals_blob, expires_at: 1.minute.from_now)
      travel 2.minutes
      get url
      assert_response :not_found
    end
  end
end

class ActiveStorage::Blobs::ExpiringRedirectControllerTest < ActionDispatch::IntegrationTest
  setup do
    @main_blob = create_main_file_blob filename: "racecar.jpg"
    @animals_blob = create_animals_file_blob filename: "racecar.jpg"
    @old_urls_expire_in = ActiveStorage.urls_expire_in
    ActiveStorage.urls_expire_in = 1.minutes
  end

  teardown do
    ActiveStorage.urls_expire_in = @old_urls_expire_in
  end

  test "signed ID within expiration date for main" do
    get rails_main_storage_redirect_url(@main_blob)
    assert_redirected_to(/racecar\.jpg/)
  end

  test "signed ID within expiration date for animals" do
    get rails_animals_storage_redirect_url(@animals_blob)
    assert_redirected_to(/racecar\.jpg/)
  end

  test "Expired signed ID for main" do
    url = rails_main_storage_redirect_url(@main_blob)
    travel 2.minutes
    get url
    assert_response :not_found
  end

  test "Expired signed ID for animals" do
    url = rails_animals_storage_redirect_url(@animals_blob)
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
