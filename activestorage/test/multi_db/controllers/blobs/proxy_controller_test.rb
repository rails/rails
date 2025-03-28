# frozen_string_literal: true

require "multi_db_test_helper"
require "database/setup"
require "minitest/mock"

module ActiveStorage::Blobs
  class ProxyControllerTest < ActionDispatch::IntegrationTest
    test "invalid main signed ID" do
      get rails_service_main_blob_proxy_url("invalid", "racecar.jpg")
      assert_response :not_found
    end

    test "invalid animals signed ID" do
      get rails_service_animals_blob_proxy_url("invalid", "racecar.jpg")
      assert_response :not_found
    end

    test "HTTP main caching" do
      get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"))
      assert_response :success
      assert_equal "max-age=3155695200, public, immutable", response.headers["Cache-Control"]
    end

    test "HTTP animals caching" do
      get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"))
      assert_response :success
      assert_equal "max-age=3155695200, public, immutable", response.headers["Cache-Control"]
    end

    test "invalidates cache and returns a 404 if the main file is not found on download" do
      blob = create_main_file_blob(filename: "racecar.jpg")
      mock_download = lambda do |_|
        raise ActiveStorage::FileNotFoundError.new "File still uploading!"
      end
      blob.service.stub(:download, mock_download) do
        get rails_main_storage_proxy_url(blob)
      end
      assert_response :not_found
      assert_equal "no-cache", response.headers["Cache-Control"]
    end

    test "invalidates cache and returns a 404 if the animals file is not found on download" do
      blob = create_animals_file_blob(filename: "racecar.jpg")
      mock_download = lambda do |_|
        raise ActiveStorage::FileNotFoundError.new "File still uploading!"
      end
      blob.service.stub(:download, mock_download) do
        get rails_animals_storage_proxy_url(blob)
      end
      assert_response :not_found
      assert_equal "no-cache", response.headers["Cache-Control"]
    end


    test "invalidates cache and returns a 500 if an error is raised on download for main" do
      blob = create_main_file_blob(filename: "racecar.jpg")
      mock_download = lambda do |_|
        raise StandardError.new "Something is not cool!"
      end
      blob.service.stub(:download, mock_download) do
        get rails_main_storage_proxy_url(blob)
      end
      assert_response :internal_server_error
      assert_equal "no-cache", response.headers["Cache-Control"]
    end

    test "invalidates cache and returns a 500 if an error is raised on download for animals" do
      blob = create_animals_file_blob(filename: "racecar.jpg")
      mock_download = lambda do |_|
        raise StandardError.new "Something is not cool!"
      end
      blob.service.stub(:download, mock_download) do
        get rails_animals_storage_proxy_url(blob)
      end
      assert_response :internal_server_error
      assert_equal "no-cache", response.headers["Cache-Control"]
    end

    test "forcing Content-Type to binary for main" do
      get rails_main_storage_proxy_url(create_main_blob(content_type: "text/html"))
      assert_equal "application/octet-stream", response.headers["Content-Type"]
    end

    test "forcing Content-Type to binary for animals" do
      get rails_animals_storage_proxy_url(create_animals_blob(content_type: "text/html"))
      assert_equal "application/octet-stream", response.headers["Content-Type"]
    end

    test "forcing Content-Disposition to attachment based on type for main" do
      get rails_main_storage_proxy_url(create_main_blob(content_type: "application/zip"))
      assert_match(/^attachment; /, response.headers["Content-Disposition"])
    end

    test "forcing Content-Disposition to attachment based on type for animals" do
      get rails_animals_storage_proxy_url(create_animals_blob(content_type: "application/zip"))
      assert_match(/^attachment; /, response.headers["Content-Disposition"])
    end

    test "caller can change disposition to attachment for main" do
      url = rails_main_storage_proxy_url(create_main_blob(content_type: "image/jpeg"), disposition: :attachment)
      get url
      assert_match(/^attachment; /, response.headers["Content-Disposition"])
    end

    test "caller can change disposition to attachment for animals" do
      url = rails_animals_storage_proxy_url(create_animals_blob(content_type: "image/jpeg"), disposition: :attachment)
      get url
      assert_match(/^attachment; /, response.headers["Content-Disposition"])
    end

    test "signed ID within expiration duration for main" do
      get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
      assert_response :success
    end

    test "signed ID within expiration duration for animals" do
      get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
      assert_response :success
    end

    test "Expired signed ID within expiration duration for main" do
      url = rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "Expired signed ID within expiration duration for animals" do
      url = rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "signed ID within expiration time for main" do
      get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"), expires_at: 1.minute.from_now)
      assert_response :success
    end

    test "signed ID within expiration time for animals" do
      get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"), expires_at: 1.minute.from_now)
      assert_response :success
    end

    test "Expired signed ID within expiration time for main" do
      url = rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"), expires_at: 1.minute.from_now)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "Expired signed ID within expiration time for animals" do
      url = rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"), expires_at: 1.minute.from_now)
      travel 2.minutes
      get url
      assert_response :not_found
    end

    test "single Byte Range for main" do
      get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=5-9" }
      assert_response :partial_content
      assert_equal "5", response.headers["Content-Length"]
      assert_equal "bytes 5-9/1124062", response.headers["Content-Range"]
      assert_equal "image/jpeg", response.headers["Content-Type"]
      assert_equal " Exif", response.body
    end

    test "single Byte Range for animals" do
      get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=5-9" }
      assert_response :partial_content
      assert_equal "5", response.headers["Content-Length"]
      assert_equal "bytes 5-9/1124062", response.headers["Content-Range"]
      assert_equal "image/jpeg", response.headers["Content-Type"]
      assert_equal " Exif", response.body
    end


    test "invalid Byte Range for main" do
      get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=*/1234" }
      assert_response :range_not_satisfiable
    end

    test "invalid Byte Range for animals" do
      get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=*/1234" }
      assert_response :range_not_satisfiable
    end

    test "multiple Byte Ranges for main" do
      boundary = SecureRandom.hex
      SecureRandom.stub :hex, boundary do
        get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=5-9,13-17" }
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

    test "multiple Byte Ranges for animals" do
      boundary = SecureRandom.hex
      SecureRandom.stub :hex, boundary do
        get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=5-9,13-17" }
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

    test "uses a Live::Response for main" do
      # This tests for a regression of #45102. If the controller doesn't respond
      # with a ActionController::Live::Response, it will serve corrupted files
      # over 5mb when using S3 services.
      request = ActionController::TestRequest.create({})
      assert_instance_of ActionController::Live::Response, ActiveStorage::Main::Blobs::ProxyController.make_response!(request)
    end

    test "uses a Live::Response for animals" do
      # This tests for a regression of #45102. If the controller doesn't respond
      # with a ActionController::Live::Response, it will serve corrupted files
      # over 5mb when using S3 services.
      request = ActionController::TestRequest.create({})
      assert_instance_of ActionController::Live::Response, ActiveStorage::Animals::Blobs::ProxyController.make_response!(request)
    end

    test "sessions are disabled for main" do
      get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"))
      assert request.session_options[:skip],
        "Expected request.session_options[:skip] to be true"
    end

    test "sessions are disabled for animals" do
      get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"))
      assert request.session_options[:skip],
        "Expected request.session_options[:skip] to be true"
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

  test "signed ID within expiration date for main" do
    get rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"))
    assert_response :success
  end

  test "signed ID within expiration date for animals" do
    get rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"))
    assert_response :success
  end

  test "Expired signed ID within expiration date for main" do
    url = rails_main_storage_proxy_url(create_main_file_blob(filename: "racecar.jpg"))
    travel 2.minutes
    get url
    assert_response :not_found
  end

  test "Expired signed ID within expiration date for animals" do
    url = rails_animals_storage_proxy_url(create_animals_file_blob(filename: "racecar.jpg"))
    travel 2.minutes
    get url
    assert_response :not_found
  end
end
