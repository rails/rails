# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::ConfiguratorTest < ActiveSupport::TestCase
  test "builds correct service instance based on service name" do
    service = ActiveStorage::Service::Configurator.build(:foo, foo: { service: "Disk", root: "path" })
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal "path", service.root
  end

  test "builds correct service instance based on lowercase service name" do
    service = ActiveStorage::Service::Configurator.build(:foo, foo: { service: "disk", root: "path" })
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal "path", service.root
  end

  test "raises error when passing non-existent service name" do
    assert_raise RuntimeError do
      ActiveStorage::Service::Configurator.build(:bigfoot, {})
    end
  end

  test "azure service is deprecated" do
    msg = <<~MSG.squish
      `ActiveStorage::Service::AzureStorageService` is deprecated and will be
      removed in Rails 8.1.
      Please try the `azure-blob` gem instead.
      This gem is not maintained by the Rails team, so please test your applications before deploying to production.
    MSG

    assert_deprecated(msg, ActiveStorage.deprecator) do
      ActiveStorage::Service::Configurator.build(:azure, azure: {
        service: "AzureStorage",
        storage_account_name: "test_account",
        storage_access_key: Base64.encode64("test_access_key").strip,
        container: "container"
      })
    end
  end

  test "builds correct service given STORAGE_URL environment variable" do
    @before_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "disk://tmp/storage"

    service = ActiveStorage::Service::Configurator.build(:env, {})
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal "tmp/storage", service.root
  ensure
    ENV["STORAGE_URL"] = @before_storage_url
  end

  test "STORAGE_URL env var with disk service root path" do
    @before_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "disk:///root/storage"

    service = ActiveStorage::Service::Configurator.build(:env, {})
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal "/root/storage", service.root
  ensure
    ENV["STORAGE_URL"] = @before_storage_url
  end

  test "STORAGE_URL env var for s3" do
    @before_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "s3://access_key_id:secret_access_key@us-east-1/your-bucket"

    service = ActiveStorage::Service::Configurator.build(:env, {})
    assert_instance_of ActiveStorage::Service::S3Service, service
    assert_equal "your-bucket", service.bucket.name

    assert_equal "us-east-1", service.client.client.config.region
    assert_equal "access_key_id", service.client.client.config.access_key_id
    assert_equal "secret_access_key", service.client.client.config.secret_access_key
  ensure
    ENV["STORAGE_URL"] = @before_storage_url
  end

  test "STORAGE_URL env var for gcs" do
    @before_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "gcs://path/to/gcs.keyfile@your_project/your-bucket"

    service = ActiveStorage::Service::Configurator.build(:env, {})
    assert_instance_of ActiveStorage::Service::GCSService, service
  ensure
    ENV["STORAGE_URL"] = @before_storage_url
  end

  test "STORAGE_URL env var for gcs with query hash" do
    @before_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "gcs://path/to/gcs.keyfile@your_project/your-bucket?public=true"

    service = ActiveStorage::Service::Configurator.build(:env, {})
    assert_instance_of ActiveStorage::Service::GCSService, service
    assert_predicate service, :public? # public only has to be truthy to set acl to public-read
  ensure
    ENV["STORAGE_URL"] = @before_storage_url
  end
end
