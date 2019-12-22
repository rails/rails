# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"
require "database/setup"

if SERVICE_CONFIGURATIONS[:s3_public]
  class ActiveStorage::Service::S3PublicServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3_public, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "public acl options" do
      assert_equal "public-read", @service.upload_options[:acl]
    end

    test "public URL generation" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

      assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws\.com\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end
  end
else
  puts "Skipping S3 Public Service tests because no S3 configuration was supplied"
end
