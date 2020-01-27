# frozen_string_literal: true

require "service/shared_service_tests"
require "uri"

if SERVICE_CONFIGURATIONS[:azure_aad]
  class ActiveStorage::Service::AzureStorageAADServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:azure_aad, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "signed URL generation" do
      url = @service.url(@key, expires_in: 5.minutes,
                         disposition: :inline, filename: ActiveStorage::Filename.new("avatar.png"), content_type: "image/png")

      assert_match(/(\S+)&rscd=inline%3B\+filename%3D%22avatar\.png%22%3B\+filename\*%3DUTF-8%27%27avatar\.png&rsct=image%2Fpng/, url)
      assert_match SERVICE_CONFIGURATIONS[:azure_aad][:container], url

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end
  end
else
  puts "Skipping Azure Storage AAD Service tests because no Azure configuration was supplied"
end
