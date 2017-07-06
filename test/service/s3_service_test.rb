require "service/shared_service_tests"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:S3, SERVICE_CONFIGURATIONS[:s3])

    include ActiveStorage::Service::SharedServiceTests
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
