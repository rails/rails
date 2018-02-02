# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if SERVICE_CONFIGURATIONS[:s3] && SERVICE_CONFIGURATIONS[:s3][:access_key_id].present?
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      begin
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
    end

    test "signed URL generation" do
      url = @service.url(FIXTURE_KEY, expires_in: 5.minutes,
        disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

      assert_match(/s3\.(\S+)?amazonaws.com.*response-content-disposition=inline.*avatar\.png.*response-content-type=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:s3][:bucket], url
    end

    test "uploading with server-side encryption" do
      config  = SERVICE_CONFIGURATIONS.deep_merge(s3: { upload: { server_side_encryption: "AES256" } })
      service = ActiveStorage::Service.configure(:s3, config)

      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        service.upload key, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert_equal "AES256", service.bucket.object(key).server_side_encryption
      ensure
        service.delete key
      end
    end

    test "delete_prefixed" do
      begin
        relative_prefix = SecureRandom.base58(24)
        key1  = relative_prefix + "/one"
        key2  = relative_prefix + "/other"
        data = "I am one of multiple files in a subdirectory"
        @service.upload key1, StringIO.new(data), checksum: Digest::MD5.base64digest(data)
        @service.upload key2, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert @service.exist?(key1)
        assert @service.exist?(key2)
        @service.delete_prefixed(relative_prefix)
        assert !@service.exist?(key1)
        assert !@service.exist?(key2)
      ensure
        @service.delete key1
        @service.delete key2
      end
    end

    test "delete_prefixed with a global prefix" do
      prefix  = SecureRandom.base58(24)
      config  = SERVICE_CONFIGURATIONS.deep_merge(s3: { prefix: prefix })
      service = ActiveStorage::Service.configure(:s3, config)

      begin
        relative_prefix = SecureRandom.base58(24)
        key1  = relative_prefix + "/one"
        key2  = relative_prefix + "/other"
        data = "I am one of multiple files in a subdirectory below a prefix"
        service.upload key1, StringIO.new(data), checksum: Digest::MD5.base64digest(data)
        service.upload key2, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert service.exist?(key1)
        assert service.exist?(key2)
        service.delete_prefixed(relative_prefix)
        assert !service.exist?(key1)
        assert !service.exist?(key2)
      ensure
        service.delete key1
        service.delete key2
      end
    end

    test "upload and download with prefix" do
      prefix  = SecureRandom.base58(24)
      config  = SERVICE_CONFIGURATIONS.deep_merge(s3: { prefix: prefix })
      service = ActiveStorage::Service.configure(:s3, config)

      begin
        key  = SecureRandom.base58(24)
        data = "I will be placed into the custom prefix"
        service.upload key, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert_equal data, service.download(key)
      ensure
        service.delete key
      end
    end

    test "upload and download with prefix that has a trailing slash" do
      prefix  = SecureRandom.base58(24) + '/'
      config  = SERVICE_CONFIGURATIONS.deep_merge(s3: { prefix: prefix })
      service = ActiveStorage::Service.configure(:s3, config)

      begin
        key  = SecureRandom.base58(24)
        data = "I will be placed into the custom prefix"
        service.upload key, StringIO.new(data), checksum: Digest::MD5.base64digest(data)

        assert_equal data, service.download(key)
      ensure
        service.delete key
      end
    end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
