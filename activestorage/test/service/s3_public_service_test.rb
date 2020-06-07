# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"
require "database/setup"

if SERVICE_CONFIGURATIONS[:s3_public]
  class ActiveStorage::Service::S3PublicServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3_public, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "public acl options" do
      assert_equal "public-read", @service.upload_options[:acl]
    end

    test "public URL generation" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

      assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws\.com\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
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

      response = Net::HTTP.get_response(URI(@service.url(key)))
      assert_equal "200", response.code
      assert_equal data, response.body
    ensure
      @service.delete key
    end
  end
else
  puts "Skipping S3 Public Service tests because no S3 configuration was supplied"
end
