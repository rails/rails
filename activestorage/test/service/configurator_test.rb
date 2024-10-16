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
end
