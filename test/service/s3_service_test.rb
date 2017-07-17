require "service/shared_service_tests"
require "httparty"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        url  = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size)

        HTTParty.put(
          url,
          body: data,
          headers: { "Content-Type" => "text/plain" },
          debug_output: STDOUT
        )

        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end

    test "signed URL generation" do
      assert_match /#{SERVICE_CONFIGURATIONS[:s3][:bucket]}\.s3.(\S+)?amazonaws.com.*response-content-disposition=inline.*avatar\.png/,
        @service.url(FIXTURE_KEY, expires_in: 5.minutes, disposition: :inline, filename: "avatar.png")
    end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
