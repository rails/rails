# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if SERVICE_CONFIGURATIONS[:digital_ocean]
  class ActiveStorage::Service::DigitalOceanServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:digital_ocean, SERVICE_CONFIGURATIONS)

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

      assert_match(/(-[-a-z0-9]+)?\.(\S+)?digitaloceanspaces.com.*response-content-disposition=inline.*avatar\.png.*response-content-type=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:digital_ocean][:bucket], url
    end

    test "configuring upload with server-side encryption" do
      config = SERVICE_CONFIGURATIONS.deep_merge(digital_ocean: { upload: { server_side_encryption: "AES256" } })

      assert_raise ActiveStorage::UnavailableConfigurationError do
        service = ActiveStorage::Service.configure(:digital_ocean, config)
      end
    end
  end
else
  puts "Skipping DigitalOcean Service tests because no DigitalOcean configuration was supplied"
end
