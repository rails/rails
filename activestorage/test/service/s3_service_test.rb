# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"
require "database/setup"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "name" do
      assert_equal :s3, @service.name
    end

    test "direct upload" do
      key      = SecureRandom.base58(24)
      data     = "Something else entirely!"
      checksum = Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      request.add_field "Content-Type", "text/plain"
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
      checksum = Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      @service.headers_for_direct_upload(key, checksum: checksum, content_type: "text/plain", filename: ActiveStorage::Filename.new("test.txt"), disposition: :attachment).each do |k, v|
        request.add_field k, v
      end
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      assert_equal("attachment; filename=\"test.txt\"; filename*=UTF-8''test.txt", @service.bucket.object(key).content_disposition)
    ensure
      @service.delete key
    end

    test "directly uploading file larger than the provided content-length does not work" do
      key      = SecureRandom.base58(24)
      data     = "Some text that is longer than the specified content length"
      checksum = Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size - 1, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      request.add_field "Content-Type", "text/plain"
      request.add_field "Content-MD5", checksum
      upload_result = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      assert_equal "403", upload_result.code
      assert_raises ActiveStorage::FileNotFoundError do
        @service.download(key)
      end
    ensure
      @service.delete key
    end

    test "upload a zero byte file" do
      blob = directly_upload_file_blob filename: "empty_file.txt", content_type: nil
      user = User.create! name: "DHH", avatar: blob

      assert_equal user.avatar.blob, blob
    end

    test "signed URL generation" do
      url = @service.url(@key, expires_in: 5.minutes,
        disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

      assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws.com.*response-content-disposition=inline.*avatar\.png.*response-content-type=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:s3][:bucket], url
    end

    test "uploading with server-side encryption" do
      service = build_service(upload: { server_side_encryption: "AES256" })

      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        service.upload key, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert_equal "AES256", service.bucket.object(key).server_side_encryption
      ensure
        service.delete key
      end
    end

    test "upload with content type" do
      key          = SecureRandom.base58(24)
      data         = "Something else entirely!"
      content_type = "text/plain"

      @service.upload(
        key,
        StringIO.new(data),
        checksum: Digest::MD5.base64digest(data),
        filename: "cool_data.txt",
        content_type: content_type
      )

      assert_equal content_type, @service.bucket.object(key).content_type
    ensure
      @service.delete key
    end

    test "upload with content disposition" do
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"

      @service.upload(
        key,
        StringIO.new(data),
        checksum: Digest::MD5.base64digest(data),
        filename: ActiveStorage::Filename.new("cool_data.txt"),
        disposition: :attachment
      )

      assert_equal("attachment; filename=\"cool_data.txt\"; filename*=UTF-8''cool_data.txt", @service.bucket.object(key).content_disposition)
    ensure
      @service.delete key
    end

    test "uploading a large object in multiple parts" do
      service = build_service(upload: { multipart_threshold: 5.megabytes })

      begin
        key  = SecureRandom.base58(24)
        data = SecureRandom.bytes(8.megabytes)

        service.upload key, StringIO.new(data), checksum: Digest::MD5.base64digest(data)
        assert data == service.download(key)
      ensure
        service.delete key
      end
    end

    private
      def build_service(configuration)
        ActiveStorage::Service.configure :s3, SERVICE_CONFIGURATIONS.deep_merge(s3: configuration)
      end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
