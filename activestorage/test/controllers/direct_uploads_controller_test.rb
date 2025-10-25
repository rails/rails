# frozen_string_literal: true

require "test_helper"

class ActiveStorage::DirectUploadsControllerTestCase < ActionDispatch::IntegrationTest
  # These tests were written assuming the test environment was loaded in the
  # dummy app which was configured to disable forgery protection.
  setup do
    @original_forgery_protection_value = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = false
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @original_forgery_protection_value
  end
end

if SERVICE_CONFIGURATIONS[:s3] && SERVICE_CONFIGURATIONS[:s3][:access_key_id].present?
  class ActiveStorage::S3DirectUploadsControllerTest < ActiveStorage::DirectUploadsControllerTestCase
    setup do
      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      checksum = OpenSSL::Digest::MD5.base64digest("Hello")
      metadata = {
        "foo" => "bar",
        "my_key_1" => "my_value_1",
        "my_key_2" => "my_value_2",
        "platform" => "my_platform",
        "library_ID" => "12345",
        "custom" => {
          "my_key_3" => "my_value_3"
        }
      }

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

      response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal metadata, details["metadata"]
        assert_equal "text/plain", details["content_type"]
        assert_match SERVICE_CONFIGURATIONS[:s3][:bucket], details["direct_upload"]["url"]
        assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws\.com/, details["direct_upload"]["url"])
        assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum, "Content-Disposition" => "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", "x-amz-meta-my_key_3" => "my_value_3" }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping S3 Direct Upload tests because no S3 configuration was supplied"
end

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::GCSDirectUploadsControllerTest < ActiveStorage::DirectUploadsControllerTestCase
    setup do
      @config = SERVICE_CONFIGURATIONS[:gcs]

      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      checksum = OpenSSL::Digest::MD5.base64digest("Hello")
      metadata = {
        "foo" => "bar",
        "my_key_1" => "my_value_1",
        "my_key_2" => "my_value_2",
        "platform" => "my_platform",
        "library_ID" => "12345",
        "custom" => {
          "my_key_3" => "my_value_3"
        }
      }

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

      response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal metadata, details["metadata"]
        assert_equal "text/plain", details["content_type"]
        assert_match %r{storage\.googleapis\.com/#{@config[:bucket]}}, details["direct_upload"]["url"]
        assert_equal({ "Content-MD5" => checksum, "Content-Disposition" => "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", "x-goog-meta-my_key_3" => "my_value_3" }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping GCS Direct Upload tests because no GCS configuration was supplied"
end

class ActiveStorage::DiskDirectUploadsControllerTest < ActiveStorage::DirectUploadsControllerTestCase
  test "creating new direct upload" do
    checksum = OpenSSL::Digest::MD5.base64digest("Hello")
    metadata = {
      "foo" => "bar",
      "my_key_1" => "my_value_1",
      "my_key_2" => "my_value_2",
      "platform" => "my_platform",
      "library_ID" => "12345"
    }

    post rails_direct_uploads_url, params: { blob: {
      filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

    response.parsed_body.tap do |details|
      assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
      assert_equal "hello.txt", details["filename"]
      assert_equal 6, details["byte_size"]
      assert_equal checksum, details["checksum"]
      assert_equal metadata, details["metadata"]
      assert_equal "text/plain", details["content_type"]
      assert_match(/rails\/active_storage\/disk/, details["direct_upload"]["url"])
      assert_equal({ "Content-Type" => "text/plain" }, details["direct_upload"]["headers"])
    end
  end

  test "creating new direct upload does not include root in json" do
    checksum = OpenSSL::Digest::MD5.base64digest("Hello")
    metadata = {
      "foo" => "bar",
      "my_key_1" => "my_value_1",
      "my_key_2" => "my_value_2",
      "platform" => "my_platform",
      "library_ID" => "12345"
    }

    set_include_root_in_json(true) do
      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }
    end

    response.parsed_body.tap do |details|
      assert_nil details["blob"]
      assert_not_nil details["id"]
    end
  end

  private
    def set_include_root_in_json(value)
      original = ActiveRecord::Base.include_root_in_json
      ActiveRecord::Base.include_root_in_json = value
      yield
    ensure
      ActiveRecord::Base.include_root_in_json = original
    end
end
