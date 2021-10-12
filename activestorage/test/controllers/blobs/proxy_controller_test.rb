# frozen_string_literal: true

require "test_helper"
require "database/setup"
require "minitest/mock"

class ActiveStorage::Blobs::ProxyControllerTest < ActionDispatch::IntegrationTest
  test "invalid signed ID" do
    get rails_service_blob_proxy_url("invalid", "racecar.jpg")
    assert_response :not_found
  end

  test "HTTP caching" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"))
    assert_response :success
    assert_equal "max-age=3155695200, public", response.headers["Cache-Control"]
  end

  test "forcing Content-Type to binary" do
    get rails_storage_proxy_url(create_blob(content_type: "text/html"))
    assert_equal "application/octet-stream", response.headers["Content-Type"]
  end

  test "forcing Content-Disposition to attachment" do
    get rails_storage_proxy_url(create_blob(content_type: "application/zip"))
    assert_match(/^attachment; /, response.headers["Content-Disposition"])
  end

  test "signed ID within expiration date" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
    assert_response :success
  end

  test "Expired signed ID" do
    url = rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
    travel 2.minutes
    get url
    assert_response :not_found
  end

  test "single Byte Range" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=5-9" }
    assert_response :partial_content
    assert_equal "5", response.headers["Content-Length"]
    assert_equal "bytes 5-9/1124062", response.headers["Content-Range"]
    assert_equal "image/jpeg", response.headers["Content-Type"]
    assert_equal " Exif", response.body
  end

  test "invalid Byte Range" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=*/1234" }
    assert_response :range_not_satisfiable
  end

  test "multiple Byte Ranges" do
    boundary = SecureRandom.hex
    SecureRandom.stub :hex, boundary do
      get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=5-9,13-17" }
      assert_response :partial_content
      assert_equal "252", response.headers["Content-Length"]
      assert_equal "multipart/byteranges; boundary=#{boundary}", response.headers["Content-Type"]
      assert_equal(
        [
          "",
          "--#{boundary}",
          "Content-Type: image/jpeg",
          "Content-Range: bytes 5-9/1124062",
          "",
          " Exif",
          "--#{boundary}",
          "Content-Type: image/jpeg",
          "Content-Range: bytes 13-17/1124062",
          "",
          "I*\u0000\b\u0000",
          "--#{boundary}--",
          ""
        ].join("\r\n"),
        response.body
      )
    end
  end
end

class ActiveStorage::Blobs::ExpiringProxyControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_urls_expire_in = ActiveStorage.urls_expire_in
    ActiveStorage.urls_expire_in = 1.minutes
  end

  teardown do
    ActiveStorage.urls_expire_in = @old_urls_expire_in
  end

  test "signed ID within expiration date" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"))
    assert_response :success
  end

  test "Expired signed ID" do
    url = rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"))
    travel 2.minutes
    get url
    assert_response :not_found
  end
end
