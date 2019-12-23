# frozen_string_literal: true

require "service/shared_service_tests"
require "net/http"

if SERVICE_CONFIGURATIONS[:gcs_public]
  class ActiveStorage::Service::GCSPublicServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:gcs_public, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "public URL generation" do
      url = @service.url(@key, filename: ActiveStorage::Filename.new("avatar.png"))

      assert_match(/storage\.googleapis\.com\/.*\/#{@key}/, url)

      response = Net::HTTP.get_response(URI(url))
      assert_equal "200", response.code
    end
  end
else
  puts "Skipping GCS Public Service tests because no GCS configuration was supplied"
end
