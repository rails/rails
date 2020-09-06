# frozen_string_literal: true

require 'service/shared_service_tests'
require 'net/http'

if SERVICE_CONFIGURATIONS[:gcs_public]
  class ActiveStorage::Service::GCSPublicServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:gcs_public, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test 'public URL generation' do
      url = @service.url(@key, filename: ActiveStorage::Filename.new('avatar.png'))

      assert_match(/storage\.googleapis\.com\/.*\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal '200', response.code
    end

    test 'direct upload' do
      key      = SecureRandom.base58(24)
      data     = 'Something else entirely!'
      checksum = Digest::MD5.base64digest(data)
      url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: 'text/plain', content_length: data.size, checksum: checksum)

      uri = URI.parse url
      request = Net::HTTP::Put.new uri.request_uri
      request.body = data
      request.add_field 'Content-Type', ''
      request.add_field 'Content-MD5', checksum
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.request request
      end

      response = Net::HTTP.get_response(URI(@service.url(key)))
      assert_equal '200', response.code
      assert_equal data, response.body
    ensure
      @service.delete key
    end
  end
else
  puts 'Skipping GCS Public Service tests because no GCS configuration was supplied'
end
