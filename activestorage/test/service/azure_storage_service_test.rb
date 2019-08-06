# frozen_string_literal: true

require "service/shared_service_tests"
require "uri"

if SERVICE_CONFIGURATIONS[:azure]
  class ActiveStorage::Service::AzureStorageServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "upload with content_type" do
      key      = SecureRandom.base58(24)
      data     = "Foobar"

      @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data), filename: ActiveStorage::Filename.new("test.txt"), content_type: "text/plain")

      url = @service.url(key, expires_in: 2.minutes, disposition: :attachment, content_type: nil, filename: ActiveStorage::Filename.new("test.html"))
      response = Net::HTTP.get_response(URI(url))
      assert_equal "text/plain", response.content_type
      assert_match(/attachment;.*test\.html/, response["Content-Disposition"])
    ensure
      @service.delete key
    end

    test "upload with content disposition" do
      key  = SecureRandom.base58(24)
      data = "Foobar"

      @service.upload(key, StringIO.new(data), checksum: Digest::MD5.base64digest(data), filename: ActiveStorage::Filename.new("test.txt"), disposition: :inline)

      assert_equal("inline; filename=\"test.txt\"; filename*=UTF-8''test.txt", @service.client.get_blob_properties(@service.container, key).properties[:content_disposition])

      url = @service.url(key, expires_in: 2.minutes, disposition: :attachment, content_type: nil, filename: ActiveStorage::Filename.new("test.html"))
      response = Net::HTTP.get_response(URI(url))
      assert_match(/attachment;.*test\.html/, response["Content-Disposition"])
    ensure
      @service.delete key
    end

    test "signed URL generation" do
      url = @service.url(@key, expires_in: 5.minutes,
        disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

      assert_match(/(\S+)&rscd=inline%3B\+filename%3D%22avatar\.png%22%3B\+filename\*%3DUTF-8%27%27avatar\.png&rsct=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:azure][:container], url
    end

    test "uploading a tempfile" do
      key  = SecureRandom.base58(24)
      data = "Something else entirely!"

      Tempfile.open do |file|
        file.write(data)
        file.rewind
        @service.upload(key, file)
      end

      assert_equal data, @service.download(key)
    ensure
      @service.delete(key)
    end
  end
else
  puts "Skipping Azure Storage Service tests because no Azure configuration was supplied"
end
