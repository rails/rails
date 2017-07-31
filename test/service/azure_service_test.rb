require "service/shared_service_tests"
require "httparty"
require "uri"

if SERVICE_CONFIGURATIONS[:azure]
  class ActiveStorage::Service::AzureServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests
  end

else
  puts "Skipping Azure Storage Service tests because no Azure configuration was supplied"
end
