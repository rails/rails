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

  test "builds correct service given STORAGE_URL environment variable" do
    @before_storage_url = ENV["STORAGE_URL"]
    ENV["STORAGE_URL"] = "disk://tmp/storage"

    service = ActiveStorage::Service::Configurator.build(:env, {})
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal "tmp/storage", service.root
  ensure
    ENV["STORAGE_URL"] = @before_storage_url
  end
end
