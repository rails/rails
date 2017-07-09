require "service/shared_service_tests"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "signed URL generation" do
      assert_match /rails-activestorage\.s3\.amazonaws\.com.*response-content-disposition=inline.*avatar\.png/,
        @service.url(FIXTURE_KEY, expires_in: 5.minutes, disposition: :inline, filename: "avatar.png")    
    end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
