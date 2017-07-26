require "test_helper"
require "database/setup"

require "active_storage/direct_uploads_controller"

if SERVICE_CONFIGURATIONS[:s3]
  class ActiveStorage::S3DirectUploadsControllerTest < ActionController::TestCase
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

      JSON.parse(@response.body).tap do |details|
        assert_match(/#{SERVICE_CONFIGURATIONS[:s3][:bucket]}\.s3.(\S+)?amazonaws\.com/, details["upload_to_url"])
        assert_equal "hello.txt", ActiveStorage::Blob.find_signed(details["signed_blob_id"]).filename.to_s
      end
    end
  end
else
  puts "Skipping S3 Direct Upload tests because no S3 configuration was supplied"
end

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::GCSDirectUploadsControllerTest < ActionController::TestCase
    setup do
      @blob = create_blob
      @routes = Routes
      @controller = ActiveStorage::DirectUploadsController.new
      @config = SERVICE_CONFIGURATIONS[:gcs]

      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      post :create, params: { blob: {
          filename: "hello.txt", byte_size: 6, checksum: Digest::MD5.base64digest("Hello"), content_type: "text/plain" } }

      JSON.parse(@response.body).tap do |details|
        assert_match %r{storage\.googleapis\.com/#{@config[:bucket]}}, details["upload_to_url"]
        assert_equal "hello.txt", ActiveStorage::Blob.find_signed(details["signed_blob_id"]).filename.to_s
      end
    end
  end
else
  puts "Skipping GCS Direct Upload tests because no GCS configuration was supplied"
end

class ActiveStorage::DiskDirectUploadsControllerTest < ActionController::TestCase
  setup do
    @blob = create_blob
    @routes = Routes
    @controller = ActiveStorage::DirectUploadsController.new
  end

  test "creating new direct upload" do
    post :create, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: Digest::MD5.base64digest("Hello"), content_type: "text/plain" } }

    JSON.parse(@response.body).tap do |details|
      assert_match /rails\/active_storage\/disk/, details["upload_to_url"]
      assert_equal "hello.txt", ActiveStorage::Blob.find_signed(details["signed_blob_id"]).filename.to_s
    end
  end
end
