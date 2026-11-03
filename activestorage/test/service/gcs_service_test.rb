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
      request.add_field "x-goog-content-length-range", "#{data.size},#{data.size}"
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      assert_equal data, @service.download(key)
    ensure
      @service.delete key
    end

    test "directly uploading file larger than the provided content-length does not work" do
      key      = SecureRandom.base58(24)
      data     = "Some text that is longer than the specified content length"
      checksum = OpenSSL::Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size - 1, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      @service.headers_for_direct_upload(key, checksum: checksum, content_length: data.size - 1).each do |k, v|
        request.add_field k, v
      end
      request.add_field "Content-Type", ""
      upload_result = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      assert_equal "400", upload_result.code
      assert_raises ActiveStorage::FileNotFoundError do
        @service.download(key)
      end
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
      @service.headers_for_direct_upload(key, checksum: checksum, content_length: data.size, filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment).each do |k, v|
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
      headers = service.headers_for_direct_upload(key, checksum: checksum, content_length: data.size, filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment)
      assert_equal("public, max-age=1800", headers["Cache-Control"])

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

    test "direct upload with cache control rejects a Content-Type the URL does not sign" do
      config_with_cache_control = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ cache_control: "public, max-age=1800" }) }
      service = ActiveStorage::Service.configure(:gcs, config_with_cache_control)

      key      = SecureRandom.base58(24)
      data     = "<html></html>"
      checksum = Digest::MD5.base64digest(data)
      url      = service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "image/png", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      service.headers_for_direct_upload(key, checksum: checksum, content_length: data.size, filename: ActiveStorage::Filename.new("test.png"), content_type: "image/png").each do |k, v|
        request.add_field k, v
      end
      request.add_field "Content-Type", "text/html"
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      assert_equal "403", response.code
      assert_not service.exist?(key)
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

    test "upload with custom_metadata" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data), content_type: "text/plain", custom_metadata: { "foo" => "baz" })

      url = @service.url(key, expires_in: 2.minutes, disposition: :inline, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))

      response = Net::HTTP.get_response(URI(url))
      assert_equal("baz", response["x-goog-meta-foo"])
    ensure
      @service.delete key
    end

    test "update custom_metadata" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      @service.upload(key, StringIO.new(data), checksum: OpenSSL::Digest::MD5.base64digest(data), disposition: :attachment, filename: ActiveStorage::Filename.new("test.html"), content_type: "text/html", custom_metadata: { "foo" => "baz" })

      @service.update_metadata(key, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain", custom_metadata: { "foo" => "bar" })
      url = @service.url(key, expires_in: 2.minutes, disposition: :attachment, content_type: "text/html", filename: ActiveStorage::Filename.new("test.html"))

      response = Net::HTTP.get_response(URI(url))
      assert_equal "text/plain", response.content_type
      assert_match(/inline;.*test.txt/, response["Content-Disposition"])
      assert_equal("bar", response["x-goog-meta-foo"])
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
        request.add_field("x-goog-content-length-range", "#{data.size},#{data.size}")
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

      test "default IAM client ADC" do
        WebMock.enable!
        config_with_adc = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ iam: true }) }
        service = ActiveStorage::Service.configure(:gcs, config_with_adc)

        stub_request(:post, "https://www.googleapis.com/oauth2/v4/token").to_return_json(body: {})
        stub_request(:post, %r{https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/.*:signBlob})
          .to_return_json(body: { "signedBlob" => "test_signed_blob" })
        key = SecureRandom.base58(24)
        service.url(key, expires_in: 2.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")
        assert_requested :post, "https://www.googleapis.com/oauth2/v4/token"
      ensure
        WebMock.disable!
      end

      test "overridden IAM client credentials" do
        WebMock.enable!
        config_with_adc = { gcs: SERVICE_CONFIGURATIONS[:gcs].merge({ iam: true }) }
        service = ActiveStorage::Service.configure(:gcs, config_with_adc)
                                        .tap { |client| client.iam_client.authorization = {} }

        stub_request(:post, "https://www.googleapis.com/oauth2/v4/token").to_return_json(body: {})
        stub_request(:post, %r{https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts/.*:signBlob})
          .to_return_json(body: { "signedBlob" => "test_signed_blob" })
        key = SecureRandom.base58(24)
        service.url(key, expires_in: 2.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")
        assert_not_requested :post, "https://www.googleapis.com/oauth2/v4/token"
      ensure
        WebMock.disable!
      end
    end
  end
else
  puts "Skipping GCS Service tests because no GCS configuration was supplied"
end

class ActiveStorage::Service::GCSServiceDirectUploadSignatureTest < ActiveSupport::TestCase
  setup do
    @signing_key = OpenSSL::PKey::RSA.new(2048)
    @service = ActiveStorage::Service.configure(:gcs, gcs: {
      service: "GCS",
      bucket: "bucket",
      cache_control: "public, max-age=1800",
      project_id: "project",
      credentials: {
        type: "service_account",
        project_id: "project",
        client_email: "uploader@project.iam.gserviceaccount.com",
        private_key: @signing_key.to_pem
      }
    })
    @checksum = OpenSSL::Digest::MD5.base64digest("Some text")
  end

  test "direct upload with cache control authorizes only an empty Content-Type" do
    url = @service.url_for_direct_upload("key", expires_in: 5.minutes, content_type: "text/plain", content_length: 9, checksum: @checksum)

    assert authorizes?(url, content_type: "", checksum: @checksum, content_length_range: "9,9")
    assert_not authorizes?(url, content_type: "text/html", checksum: @checksum, content_length_range: "9,9")
  end

  test "direct upload with cache control authorizes only the declared checksum" do
    url = @service.url_for_direct_upload("key", expires_in: 5.minutes, content_type: "text/plain", content_length: 9, checksum: @checksum)

    assert authorizes?(url, content_type: "", checksum: @checksum, content_length_range: "9,9")
    assert_not authorizes?(url, content_type: "", checksum: OpenSSL::Digest::MD5.base64digest("Other text"), content_length_range: "9,9")
  end

  test "direct upload authorizes only the declared content length" do
    url = @service.url_for_direct_upload("key", expires_in: 5.minutes, content_type: "text/plain", content_length: 9, checksum: @checksum)

    assert authorizes?(url, content_type: "", checksum: @checksum, content_length_range: "9,9")
    assert_not authorizes?(url, content_type: "", checksum: @checksum, content_length_range: "0,1000")
    assert_not authorizes?(url, content_type: "", checksum: @checksum, content_length_range: nil)
  end

  test "direct upload headers with cache control include Cache-Control" do
    headers = @service.headers_for_direct_upload("key", checksum: @checksum, content_length: 9, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")

    assert_equal "public, max-age=1800", headers["Cache-Control"]
  end

  test "direct upload headers include the declared content length range" do
    headers = @service.headers_for_direct_upload("key", checksum: @checksum, content_length: 9, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")

    assert_equal "9,9", headers["x-goog-content-length-range"]
  end

  private
    # Rebuilds the string that GCS verifies a V2 signed PUT URL against.
    def authorizes?(url, content_type:, checksum:, content_length_range:)
      query = Rack::Utils.parse_query(URI(url).query)
      extension_headers = content_length_range ? "x-goog-content-length-range:#{content_length_range}\n" : ""
      string_to_sign = ["PUT", checksum, content_type, query["Expires"], "#{extension_headers}/bucket/key"].join("\n")

      @signing_key.public_key.verify(OpenSSL::Digest::SHA256.new, Base64.strict_decode64(query["Signature"].to_s), string_to_sign)
    end
end
