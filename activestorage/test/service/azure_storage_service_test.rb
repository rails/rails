# frozen_string_literal: true

require "service/shared_service_tests"
require "uri"

if SERVICE_CONFIGURATIONS[:azure]
  class ActiveStorage::Service::AzureStorageServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "signed URL generation" do
      url = @service.url(@key, expires_in: 5.minutes,
        disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

      assert_match(/(\S+)&rscd=inline%3B\+filename%3D%22avatar\.png%22%3B\+filename\*%3DUTF-8%27%27avatar\.png&rsct=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:azure][:container], url
    end

    test "uploading a tempfile" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"

        Tempfile.open("test") do |file|
          file.write(data)
          file.rewind
          @service.upload(key, file)
        end

        assert_equal data, @service.download(key)
      ensure
        @service.delete(key)
      end
    end
  end
else
  puts "Skipping Azure Storage Service tests because no Azure configuration was supplied"
end
