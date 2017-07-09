require "test_helper"
require "database/setup"

require "action_controller"
require "action_controller/test_case"

require "active_storage/direct_uploads_controller"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::DirectUploadsControllerTest < ActionController::TestCase
    setup do
      @blob = create_blob
      @routes = Routes
      @controller = ActiveStorage::DirectUploadsController.new

      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      post :create, params: { blob: {
          filename: "hello.txt", byte_size: 6, checksum: Digest::MD5.base64digest("Hello"), content_type: "text/plain" } }

      details = JSON.parse(@response.body)

      assert_match /rails-activestorage\.s3.amazonaws\.com/, details["url"]
      assert_equal "hello.txt", GlobalID::Locator.locate_signed(details["sgid"]).filename.to_s
    end
  end
else
  puts "Skipping Direct Upload tests because no S3 configuration was supplied"
end
