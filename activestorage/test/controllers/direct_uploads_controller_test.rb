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
      checksum = OpenSSL::Digest::MD5.base64digest("Hello")
      metadata = {
        "foo": "bar",
        "my_key_1": "my_value_1",
        "my_key_2": "my_value_2",
        "platform": "my_platform",
        "library_ID": "12345"
      }

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

      response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal metadata, details["metadata"].transform_keys(&:to_sym)
        assert_equal "text/plain", details["content_type"]
        assert_match SERVICE_CONFIGURATIONS[:s3][:bucket], details["direct_upload"]["url"]
        assert_match(/s3(-[-a-z0-9]+)?\.(\S+)?amazonaws\.com/, details["direct_upload"]["url"])
        assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum, "Content-Disposition" => "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt" }, details["direct_upload"]["headers"])
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
      checksum = OpenSSL::Digest::MD5.base64digest("Hello")
      metadata = {
        "foo": "bar",
        "my_key_1": "my_value_1",
        "my_key_2": "my_value_2",
        "platform": "my_platform",
        "library_ID": "12345"
      }

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

      @response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal metadata, details["metadata"].transform_keys(&:to_sym)
        assert_equal "text/plain", details["content_type"]
        assert_match %r{storage\.googleapis\.com/#{@config[:bucket]}}, details["direct_upload"]["url"]
        assert_equal({ "Content-MD5" => checksum, "Content-Disposition" => "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt" }, details["direct_upload"]["headers"])
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
      checksum = OpenSSL::Digest::MD5.base64digest("Hello")
      metadata = {
        "foo": "bar",
        "my_key_1": "my_value_1",
        "my_key_2": "my_value_2",
        "platform": "my_platform",
        "library_ID": "12345"
      }

      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

      @response.parsed_body.tap do |details|
        assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
        assert_equal "hello.txt", details["filename"]
        assert_equal 6, details["byte_size"]
        assert_equal checksum, details["checksum"]
        assert_equal metadata, details["metadata"].transform_keys(&:to_sym)
        assert_equal "text/plain", details["content_type"]
        assert_match %r{#{@config[:storage_account_name]}\.blob\.core\.windows\.net/#{@config[:container]}}, details["direct_upload"]["url"]
        assert_equal({ "Content-Type" => "text/plain", "Content-MD5" => checksum, "x-ms-blob-content-disposition" => "inline; filename=\"hello.txt\"; filename*=UTF-8''hello.txt", "x-ms-blob-type" => "BlockBlob" }, details["direct_upload"]["headers"])
      end
    end
  end
else
  puts "Skipping Azure Storage Direct Upload tests because no Azure Storage configuration was supplied"
end

class ActiveStorage::DiskDirectUploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @old_validators = User._validators.deep_dup
    @old_callbacks = User._validate_callbacks.deep_dup
  end

  teardown do
    User.destroy_all
    ActiveStorage::Blob.all.each(&:purge)

    User.clear_validators!
    # NOTE: `clear_validators!` clears both registered validators and any
    # callbacks registered by `validate()`, so ensure that both are restored
    User._validators = @old_validators if @old_validators
    User._validate_callbacks = @old_callbacks if @old_callbacks
  end

  test "creating new direct upload" do
    checksum = OpenSSL::Digest::MD5.base64digest("Hello")
    metadata = {
      "foo": "bar",
      "my_key_1": "my_value_1",
      "my_key_2": "my_value_2",
      "platform": "my_platform",
      "library_ID": "12345"
    }

    post rails_direct_uploads_url, params: { blob: {
      filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }

    assert_response :success

    @response.parsed_body.tap do |details|
      assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
      assert_equal "hello.txt", details["filename"]
      assert_equal 6, details["byte_size"]
      assert_equal checksum, details["checksum"]
      assert_equal metadata, details["metadata"].transform_keys(&:to_sym)
      assert_equal "text/plain", details["content_type"]
      assert_match(/rails\/active_storage\/disk/, details["direct_upload"]["url"])
      assert_equal({ "Content-Type" => "text/plain" }, details["direct_upload"]["headers"])
    end
  end

  test "creating new direct upload does not include root in json" do
    checksum = OpenSSL::Digest::MD5.base64digest("Hello")
    metadata = {
      "foo": "bar",
      "my_key_1": "my_value_1",
      "my_key_2": "my_value_2",
      "platform": "my_platform",
      "library_ID": "12345"
    }

    set_include_root_in_json(true) do
      post rails_direct_uploads_url, params: { blob: {
        filename: "hello.txt", byte_size: 6, checksum: checksum, content_type: "text/plain", metadata: metadata } }
    end

    @response.parsed_body.tap do |details|
      assert_nil details["blob"]
      assert_not_nil details["id"]
    end
  end

  test "creating new direct upload with model with no active storage validations" do
    # validations that aren't active storage validations are ignored
    User.validates :name, length: { minimum: 2 }

    file = file_fixture("racecar.jpg").open
    checksum = Digest::MD5.base64digest(file.read)
    metadata = {
      "foo": "bar",
      "my_key_1": "my_value_1",
      "my_key_2": "my_value_2",
      "platform": "my_platform",
      "library_ID": "12345"
    }

    post rails_direct_uploads_url, params: { blob: {
      filename: "racecar.jpg", byte_size: file.size, checksum: checksum, content_type: "image/jpg", metadata: metadata, model: "User" } }

    assert_response :success

    @response.parsed_body.tap do |details|
      assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
      assert_equal "racecar.jpg", details["filename"]
      assert_equal file.size, details["byte_size"]
      assert_equal checksum, details["checksum"]
      assert_equal metadata, details["metadata"].transform_keys(&:to_sym)
      assert_equal "image/jpg", details["content_type"]
      assert_match(/rails\/active_storage\/disk/, details["direct_upload"]["url"])
      assert_equal({ "Content-Type" => "image/jpg" }, details["direct_upload"]["headers"])
    end
  end

  test "creating new direct upload with model where validations pass" do
    User.validates :avatar, attachment_content_type: { with: /\Aimage\//, message: "must be an image" }
    User.validates :avatar, attachment_byte_size: { maximum: 50.megabytes, message: "can't be larger than 50 MB" }

    file = file_fixture("racecar.jpg").open
    checksum = Digest::MD5.base64digest(file.read)
    metadata = {
      "foo": "bar",
      "my_key_1": "my_value_1",
      "my_key_2": "my_value_2",
      "platform": "my_platform",
      "library_ID": "12345"
    }

    post rails_direct_uploads_url, params: { blob: {
      filename: "racecar.jpg", byte_size: file.size, checksum: checksum, content_type: "image/jpg", metadata: metadata, model: "User" } }

    assert_response :success

    @response.parsed_body.tap do |details|
      assert_equal ActiveStorage::Blob.find(details["id"]), ActiveStorage::Blob.find_signed!(details["signed_id"])
      assert_equal "racecar.jpg", details["filename"]
      assert_equal file.size, details["byte_size"]
      assert_equal checksum, details["checksum"]
      assert_equal metadata, details["metadata"].transform_keys(&:to_sym)
      assert_equal "image/jpg", details["content_type"]
      assert_match(/rails\/active_storage\/disk/, details["direct_upload"]["url"])
      assert_equal({ "Content-Type" => "image/jpg" }, details["direct_upload"]["headers"])
    end
  end

  test "creating new direct upload with model where validations fail" do
    User.validates :avatar, attachment_content_type: { with: /\Atext\//, message: "must be a text file" }
    User.validates :avatar, attachment_byte_size: { minimum: 50.megabytes, message: "can't be smaller than 50 MB" }

    file = file_fixture("racecar.jpg").open
    checksum = Digest::MD5.base64digest(file.read)
    metadata = {
      "foo": "bar",
      "my_key_1": "my_value_1",
      "my_key_2": "my_value_2",
      "platform": "my_platform",
      "library_ID": "12345"
    }

    post rails_direct_uploads_url, params: { blob: {
      filename: "racecar.jpg", byte_size: file.size, checksum: checksum, content_type: "image/jpg", metadata: metadata, model: "User" } }

    assert_response :unprocessable_entity
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
