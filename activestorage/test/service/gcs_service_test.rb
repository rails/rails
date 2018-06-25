# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::Service::GCSServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)

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
        request.add_field "Content-Type", ""
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
      assert_match(/storage\.googleapis\.com\/.*response-content-disposition=inline.*test\.txt.*response-content-type=text%2Fplain/,
        @service.url(@key, expires_in: 2.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain"))
    end

    test "signed URL response headers" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data))

        url = @service.url(key, expires_in: 2.minutes, disposition: :inline, filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")
        response = Net::HTTP.get_response(URI(url))
        assert_equal "text/plain", response.header["Content-Type"]
      ensure
        @service.delete key
      end
    end
  end
else
  puts "Skipping GCS Service tests because no GCS configuration was supplied"
end
