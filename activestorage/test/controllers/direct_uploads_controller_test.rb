# frozen_string_literal: true

require "test_helper"
require "database/setup"

if SERVICE_CONFIGURATIONS[:s3] && SERVICE_CONFIGURATIONS[:s3][:access_key_id].present?
  class ActiveStorage::S3DirectUploadsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:s3, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      checksum = Digest::MD5.base64digest("Hello")

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain" } }

      response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal "text/plain", details["content_type"]
        assert_match SERVICE_CONFIGURATIONS[:s3][:bucket], details["direct_upload"]["url"]
        assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws\.com/, details["direct_upload"]["url"])
        assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping S3 Direct Upload tests because no S3 configuration was supplied"
end

if SERVICE_CONFIGURATIONS[:gcs]
  class ActiveStorage::GCSDirectUploadsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @config = SERVICE_CONFIGURATIONS[:gcs]

      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:gcs, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      checksum = Digest::MD5.base64digest("Hello")

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain" } }

      @response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal "text/plain", details["content_type"]
        assert_match %r{storage\.googleapis\.com/#{@config[:bucket]}}, details["direct_upload"]["url"]
        assert_equal({ "Content-MD5" => checksum }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping GCS Direct Upload tests because no GCS configuration was supplied"
end

if SERVICE_CONFIGURATIONS[:azure]
  class ActiveStorage::AzureStorageDirectUploadsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @config = SERVICE_CONFIGURATIONS[:azure]

      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:azure, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      checksum = Digest::MD5.base64digest("Hello")

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain" } }

      @response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal "text/plain", details["content_type"]
        assert_match %r{#{@config[:storage_account_name]}\.blob\.core\.windows\.net/#{@config[:container]}}, details["direct_upload"]["url"]
        assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum, "x-ms-blob-type" => "BlockBlob" }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping Azure Storage Direct Upload tests because no Azure Storage configuration was supplied"
end

if SERVICE_CONFIGURATIONS[:digital_ocean] && SERVICE_CONFIGURATIONS[:digital_ocean][:spaces_access_key].present?
  class ActiveStorage::DigitalOceanDirectUploadsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @old_service = ActiveStorage::Blob.service
      ActiveStorage::Blob.service = ActiveStorage::Service.configure(:digital_ocean, SERVICE_CONFIGURATIONS)
    end

    teardown do
      ActiveStorage::Blob.service = @old_service
    end

    test "creating new direct upload" do
      checksum = Digest::MD5.base64digest("Hello")

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain" } }

      response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal "text/plain", details["content_type"]
        assert_match SERVICE_CONFIGURATIONS[:digital_ocean][:bucket], details["direct_upload"]["url"]
        assert_match(/(-[-a-z0-9]+)?\.(\S+)?digitaloceanspaces\.com/, details["direct_upload"]["url"])
        assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping Digital Ocean Direct Upload tests because no Digital Ocean configuration was supplied"
end

class ActiveStorage::DiskDirectUploadsControllerTest < ActionDispatch::IntegrationTest
  test "creating new direct upload" do
    checksum = Digest::MD5.base64digest("Hello")

    post rails_direct_uploads_url, params: { blob: {
      filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain" } }

    @response.parsed_body.tap do |details|
      assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed(details["signed_id"])
      assert_equal "hello.txt", details["filename"]
      assert_equal 6, details["byte_size"]
      assert_equal checksum, details["checksum"]
      assert_equal "text/plain", details["content_type"]
      assert_match(/rails\/active_storage\/disk/, details["direct_upload"]["url"])
      assert_equal({ "Content-Type" => "text/plain" }, details["direct_upload"]["headers"])
    end
  end

  test "creating new direct upload does not include root in json" do
    checksum = Digest::MD5.base64digest("Hello")

    set_include_root_in_json(true) do
      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain" } }
    end

    @response.parsed_body.tap do |details|
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
