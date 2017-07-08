require "service/shared_service_tests"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
