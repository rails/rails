# frozen_string_literal: true

require "test_helper"

class ActiveStorage::Service::RegistryTest < ActiveSupport::TestCase
  test "inspect attributes" do
    registry = ActiveStorage::Service::Registry.new({})
    assert_match(/#<ActiveStorage::Service::Registry>/, registry.inspect)
  end

  test "inspect attributes with config" do
    config = {
      local: { service: "Disk", root: "/tmp/active_storage_registry_test" },
      tmp: { service: "Disk", root: "/tmp/active_storage_registry_test_tmp" },
    }

    registry = ActiveStorage::Service::Registry.new(config)
    assert_match(/#<ActiveStorage::Service::Registry configurations=\[:local, :tmp\]>/, registry.inspect)
  end
end
