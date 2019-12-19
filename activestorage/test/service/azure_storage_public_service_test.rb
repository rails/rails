# frozen_string_literal: true

require "service/shared_service_tests"
require "uri"

if SERVICE_CONFIGURATIONS[:azure_public]
  class ActiveStorage::Service::AzureStoragePublicServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:azure_public, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "public URL generation" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

      assert_match(/.*\.blob\.core\.windows\.net\/.*\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end
  end
else
  puts "Skipping Azure Storage Public Service tests because no Azure configuration was supplied"
end
