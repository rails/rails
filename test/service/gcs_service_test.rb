require "service/shared_service_tests"
require "httparty"

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::Service::GCSServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      begin
        key      = SecureRandom.base58(24)
        data     = "Something else entirely!"
        checksum = Digest::MD5.base64digest(data)
        url      = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size, checksum: checksum)

        HTTParty.put(
          url,
          body: data,
          headers: { "Content-Type" => "text/plain", "Content-MD5" => checksum },
          debug_output: STDOUT
        )

        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end

    test "signed URL generation" do
      freeze_time do
        url = SERVICE.bucket.signed_url(FIXTURE_KEY, expires: 120) +
          "&response-content-disposition=inline%3B+filename%3D%22test.txt%22" +
          "&response-content-type=text%2Fplain"

        assert_equal url, @service.url(FIXTURE_KEY, expires_in: 2.minutes, disposition: :inline, filename: "test.txt", content_type: "text/plain")
      end
    end
  end
else
  puts "Skipping GCS Service tests because no GCS configuration was supplied"
end
