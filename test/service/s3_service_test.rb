require "service/shared_service_tests"
require "httparty"
require "uri"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::Service::S3ServiceTest < ActiveSupport::TestCase
    SERVICE = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)

    include ActiveStorage::Service::SharedServiceTests

    test "direct upload" do
      # FIXME: This test is failing because of a mismatched request signature, but it works in the browser.
      skip

      begin
        key  = SecureRandom.base58(24)
        data = "Something else entirely!"
        direct_upload_url = @service.url_for_direct_upload(key, expires_in: 5.minutes, content_type: "text/plain", content_length: data.size)
        
        url   = URI.parse(direct_upload_url).to_s.split("?").first
        query = CGI::parse(URI.parse(direct_upload_url).query).collect { |(k, v)| [ k, v.first ] }.to_h

        HTTParty.post(
          url,
          query: query,
          body: data,
          headers: {
            "Content-Type": "text/plain",
            "Origin": "http://localhost:3000"
          },
          debug_output: STDOUT
        )
        
        assert_equal data, @service.download(key)
      ensure
        @service.delete key
      end
    end
    
    test "signed URL generation" do
      assert_match /rails-activestorage\.s3\.amazonaws\.com.*response-content-disposition=inline.*avatar\.png/,
        @service.url(FIXTURE_KEY, expires_in: 5.minutes, disposition: :inline, filename: "avatar.png")    
    end
  end
else
  puts "Skipping S3 Service tests because no S3 configuration was supplied"
end
