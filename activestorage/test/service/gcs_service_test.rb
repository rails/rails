# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::Service::GCSServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "name" do
      assert_equal :gcs, @service.name
    end

    test "direct upload" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      checksum = OpenSSL::Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      request.add_field "Content-Type", ""
      request.add_field "Content-MD5", checksum
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      assert_equal data, @service.download(key)
    ensure
      @service.delete key
    end

    test "direct upload with content disposition" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      checksum = OpenSSL::Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      @service.headers_for_direct_upload(key, checksum: checksum, filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment).each do |k, v|
        request.add_field k, v
      end
      request.add_field "Content-Type", ""
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      url = @service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))
      response = Net::HTTP.get_response(URI(url))
      assert_equal("attachment; filename=\"test.txt\"; filename*=UTF-8''test.txt", response["Content-Disposition"])
    ensure
      @service.delete key
    end

    test "direct upload with cache control" do
      config_with_cache_control = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ cache_control: "public, max-age=1800" }) }
      service = ActiveStorage::Service.configure(:gcs, config_with_cache_control)

      key      = SecureRandom.base58(24)
      data     = "Some text"
      checksum = Digest::MD5.base64digest(data)
      url      = service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      headers = service.headers_for_direct_upload(key, checksum: checksum, filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment)
      assert_equal(headers["Cache-Control"], "public, max-age=1800")

      headers.each do |k, v|
        request.add_field k, v
      end
      request.add_field "Content-Type", ""
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      url = service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))
      response = Net::HTTP.get_response(URI(url))
      assert_equal("public, max-age=1800", response["Cache-Control"])
    ensure
      service.delete(key)
    end

    test "upload with content_type and content_disposition" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"

      @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), disposition: :attachment, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")

      url = @service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))
      response = Net::HTTP.get_response(URI(url))
      assert_equal "text/plain", response.content_type
      assert_match(/attachment;.*test.txt/, response["Content-Disposition"])
    ensure
      @service.delete key
    end

    test "upload with content_type" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"

      @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), content_type: "text/plain")

      url = @service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))
      response = Net::HTTP.get_response(URI(url))
      assert_equal "text/plain", response.content_type
      assert_match(/inline;.*test.html/, response["Content-Disposition"])
    ensure
      @service.delete key
    end

    test "upload with cache_control" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"

      config_with_cache_control = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ cache_control: "public, max-age=1800" }) }
      service = ActiveStorage::Service.configure(:gcs, config_with_cache_control)

      service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data), content_type: "text/plain")

      url = service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))

      response = Net::HTTP.get_response(URI(url))
      assert_equal "public, max-age=1800", response["Cache-Control"]
    ensure
      service.delete key
    end

    test "update metadata" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), disposition: :attachment, filename: ActiveStorage::Filename.new("test.html"), content_type: "text/html")

      @service.update_metadata(key, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")
      url = @service.url(key, expires_in: 2.minutes, disposition: :attachment, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))

      response = Net::HTTP.get_response(URI(url))
      assert_equal "text/plain", response.content_type
      assert_match(/inline;.*test.txt/, response["Content-Disposition"])
    ensure
      @service.delete key
    end

    test "signed URL generation" do
      assert_match(/storage\.googleapis\.com\/.*response-content-disposition=inline.*test\.txt.*response-content-type=text%2Fplain/,
        @service.url(@key, expires_in: 2.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain"))
    end

    if SERVICE_CONFIGURATIONS[:gcs].key?(:gsa_email)
      test "direct upload with IAM signing" do
        config_with_iam = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ iam: true }) }
        service = ActiveStorage::Service.configure(:gcs, config_with_iam)

        key      = SecureRandom.base58(24)
        data     = "Some text"
        checksum = Digest::MD5.base64digest(data)
        url      = service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

        uri = URI.parse(url)
        request = Net::HTTP::Put.new(uri.request_uri)
        request.body = data
        request.add_field("Content-Type", "")
        request.add_field("Content-MD5", checksum)
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request request
        end

        assert_equal data, service.download(key)
      ensure
        service.delete key
      end

      test "url with IAM signing" do
        config_with_iam = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ iam: true }) }
        service = ActiveStorage::Service.configure(:gcs, config_with_iam)

        key = SecureRandom.base58(24)
        assert_match(/storage\.googleapis\.com\/.*response-content-disposition=inline.*test\.txt.*response-content-type=text%2Fplain/,
          service.url(key, expires_in: 2.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain"))
      end
    end
  end
else
  puts "Skipping GCS Service tests because no GCS configuration was supplied"
end
