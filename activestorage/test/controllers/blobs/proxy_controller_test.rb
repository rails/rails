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
    assert_equal "max-age=3155695200, public, immutable", response.headers["Cache-Control"]
  end

  test "invalidates cache and returns a 404 if the file is not found on download" do
    blob = create_file_blob(filename: "racecar.jpg")
    mock_download = lambda do |_|
      raise ActiveStorage::FileNotFoundError.new "File still uploading!"
    end
    blob.service.stub(:download, mock_download) do
      get rails_storage_proxy_url(blob)
    end
    assert_response :not_found
    assert_equal "no-cache", response.headers["Cache-Control"]
  end


  test "invalidates cache and returns a 500 if an error is raised on download" do
    blob = create_file_blob(filename: "racecar.jpg")
    mock_download = lambda do |_|
      raise StandardError.new "Something is not cool!"
    end
    blob.service.stub(:download, mock_download) do
      get rails_storage_proxy_url(blob)
    end
    assert_response :internal_server_error
    assert_equal "no-cache", response.headers["Cache-Control"]
  end


  test "forcing Content-Type to binary" do
    get rails_storage_proxy_url(create_blob(content_type: "text/html"))
    assert_equal "application/octet-stream", response.headers["Content-Type"]
  end

  test "forcing Content-Disposition to attachment based on type" do
    get rails_storage_proxy_url(create_blob(content_type: "application/zip"))
    assert_match(/^attachment; /, response.headers["Content-Disposition"])
  end

  test "caller can change disposition to attachment" do
    url = rails_storage_proxy_url(create_blob(content_type: "image/jpeg"), disposition: :attachment)
    get url
    assert_match(/^attachment; /, response.headers["Content-Disposition"])
  end

  test "signed ID within expiration duration" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
    assert_response :success
  end

  test "Expired signed ID within expiration duration" do
    url = rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"), expires_in: 1.minute)
    travel 2.minutes
    get url
    assert_response :not_found
  end

  test "signed ID within expiration time" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"), expires_at: 1.minute.from_now)
    assert_response :success
  end

  test "Expired signed ID within expiration time" do
    url = rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"), expires_at: 1.minute.from_now)
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

  test "single Byte Range larger than streaming_chunk_max_size is streamed in chunks" do
    blob = create_file_blob(filename: "racecar.jpg")
    read_sizes = []
    download_chunk = blob.service.method(:download_chunk)

    with_streaming_chunk_max_size(100.kilobytes) do
      blob.service.stub(:download_chunk, ->(key, range) { read_sizes << range.size; download_chunk.(key, range) }) do
        get rails_storage_proxy_url(blob), headers: { "Range" => "bytes=100-" }
      end
    end

    assert_response :partial_content
    assert_equal "1123962", response.headers["Content-Length"]
    assert_equal "bytes 100-1124061/1124062", response.headers["Content-Range"]
    assert_equal file_fixture("racecar.jpg").binread[100..], response.body
    assert_equal 100.kilobytes, read_sizes.max
  end

  test "Byte Range is too big overall" do
    with_streaming_chunk_max_size(8.bytes) do
      get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg")), headers: { "Range" => "bytes=0-5,6-12" }
      assert_response :range_not_satisfiable
    end
  end

  test "multiple Byte Ranges" do
    previous_streaming_max_ranges = ActiveStorage.streaming_max_ranges
    ActiveStorage.streaming_max_ranges = 2

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
  ensure
    ActiveStorage.streaming_max_ranges = previous_streaming_max_ranges
  end

  test "uses a Live::Response" do
    # This tests for a regression of #45102. If the controller doesn't respond
    # with an ActionController::Live::Response, it will serve corrupted files
    # over 5mb when using S3 services.
    request = ActionController::TestRequest.create({})
    assert_instance_of ActionController::Live::Response, ActiveStorage::Blobs::ProxyController.make_response!(request)
  end

  test "sessions are disabled" do
    get rails_storage_proxy_url(create_file_blob(filename: "racecar.jpg"))
    assert request.session_options[:skip],
      "Expected request.session_options[:skip] to be true"
  end

  test "rails_storage_proxy include Content-Length header" do
    Rails.application.config.active_storage.resolve_model_to_route = :rails_storage_proxy
    blob = create_file_blob(filename: "racecar.jpg")

    get rails_storage_proxy_url(blob)

    assert_response :success
    assert_not_nil response.headers["Content-Length"], "Content-Length header should be included in proxy mode"
    assert_equal blob.byte_size.to_s, response.headers["Content-Length"], "Content-Length header should match blob size"
  end

  test "Content-Length header is passed to the server when streaming" do
    blob = create_file_blob(filename: "racecar.jpg")

    status, headers, _body = Rails.application.call(Rack::MockRequest.env_for(rails_storage_proxy_url(blob)))

    assert_equal 200, status
    assert_equal blob.byte_size.to_s, headers["content-length"]
  end

  test "Content-Length header is passed to the server when streaming a byte range" do
    blob = create_file_blob(filename: "racecar.jpg")

    status, headers, _body = Rails.application.call(Rack::MockRequest.env_for(rails_storage_proxy_url(blob), "HTTP_RANGE" => "bytes=5-9"))

    assert_equal 206, status
    assert_equal "5", headers["content-length"]
  end

  test "returns a 404 without range headers if the file is not found on a byte range download" do
    blob = create_file_blob(filename: "racecar.jpg")
    mock_download_chunk = lambda do |_, _|
      raise ActiveStorage::FileNotFoundError.new "File still uploading!"
    end

    status, headers, _body = blob.service.stub(:download_chunk, mock_download_chunk) do
      Rails.application.call(Rack::MockRequest.env_for(rails_storage_proxy_url(blob), "HTTP_RANGE" => "bytes=5-9"))
    end

    assert_equal 404, status
    assert_nil headers["content-range"]
    assert_nil headers["content-length"]
  end

  private
    def with_streaming_chunk_max_size(size)
      old_size = ActiveStorage.streaming_chunk_max_size
      ActiveStorage.streaming_chunk_max_size = size
      yield
    ensure
      ActiveStorage.streaming_chunk_max_size = old_size
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
