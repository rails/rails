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

  test "configuration from a disk URL with an absolute root" do
    assert_equal({ service: "Disk", root: "/var/storage" }, configuration_from_url("disk:///var/storage"))
  end

  test "configuration from a disk URL with a relative root" do
    assert_equal({ service: "Disk", root: "my/root/path" }, configuration_from_url("disk://my/root/path"))
  end

  test "configuration from a disk URL without a root" do
    assert_raises(ArgumentError) { configuration_from_url("disk://") }
  end

  test "configuration from an S3 URL" do
    assert_equal(
      { service: "S3", region: "us-east-1", bucket: "your-bucket", access_key_id: "key", secret_access_key: "secret" },
      configuration_from_url("s3://key:secret@us-east-1/your-bucket")
    )
  end

  test "configuration from an S3 URL decodes credentials" do
    config = configuration_from_url("s3://key:se%2Fcr%2Bet@us-east-1/your-bucket")

    assert_equal "se/cr+et", config[:secret_access_key]
  end

  test "configuration from an S3 URL without credentials" do
    assert_equal(
      { service: "S3", region: "us-east-1", bucket: "your-bucket" },
      configuration_from_url("s3://us-east-1/your-bucket")
    )
  end

  test "configuration from an S3 URL builds the service" do
    config = configuration_from_url("s3://key:secret@us-east-1/your-bucket")
    service = ActiveStorage::Service::Configurator.build(:foo, foo: config)

    assert_instance_of ActiveStorage::Service::S3Service, service
    assert_equal "your-bucket", service.bucket.name
  end

  test "configuration from an S3 URL without a bucket" do
    assert_raises(ArgumentError) { configuration_from_url("s3://key:secret@us-east-1") }
  end

  test "configuration from an S3 URL with a query" do
    error = assert_raises(ArgumentError) do
      configuration_from_url("s3://key:secret@auto/your-bucket?endpoint=https://example.com")
    end

    assert_includes error.message, "storage.yml"
  end

  test "configuration from a GCS URL" do
    assert_equal(
      { service: "GCS", credentials: "path/to/gcs.keyfile", project: "your_project", bucket: "your-bucket" },
      configuration_from_url("gcs://path/to/gcs.keyfile@your_project/your-bucket")
    )
  end

  test "configuration from a GCS URL with an absolute keyfile" do
    config = configuration_from_url("gcs:///etc/gcs.keyfile@your_project/your-bucket")

    assert_equal "/etc/gcs.keyfile", config[:credentials]
  end

  test "configuration from a GCS URL without a keyfile" do
    assert_equal(
      { service: "GCS", project: "your_project", bucket: "your-bucket" },
      configuration_from_url("gcs://your_project/your-bucket")
    )
  end

  test "configuration from a GCS URL without a bucket" do
    assert_raises(ArgumentError) { configuration_from_url("gcs://path/to/gcs.keyfile@your_project") }
  end

  test "configuration from a URL with an unsupported scheme" do
    error = assert_raises(ArgumentError) { configuration_from_url("azure://secret@account/container") }

    assert_includes error.message, "disk://"
    assert_not_includes error.message, "secret"
  end

  test "configuration from an invalid URL doesn't expose it" do
    error = assert_raises(ArgumentError) { configuration_from_url("s3://key:se/cret@us-east-1/your-bucket") }

    assert_not_includes error.message, "cret"
    assert_nil error.cause
  end

  test "inspect attributes" do
    config = {
      local: { service: "Disk", root: "/tmp/active_storage_configurator_test" },
      tmp: { service: "Disk", root: "/tmp/active_storage_configurator_test_tmp" },
    }

    configurator = ActiveStorage::Service::Configurator.new(config)
    assert_match(/#<ActiveStorage::Service::Configurator configurations=\[:local, :tmp\]>/, configurator.inspect)

    configurator = ActiveStorage::Service::Configurator.new({})
    assert_match(/#<ActiveStorage::Service::Configurator>/, configurator.inspect)
  end

  private
    def configuration_from_url(url)
      ActiveStorage::Service::Configurator.configuration_from_url(url)
    end
end
