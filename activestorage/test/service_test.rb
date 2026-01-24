# frozen_string_literal: true

require "test_helper"

class ActiveStorage::ServiceTest < ActiveSupport::TestCase
  test "inspect attributes" do
    config = {
      local: { service: "Disk", root: "/tmp/active_storage_service_test" },
      tmp: { service: "Disk", root: "/tmp/active_storage_service_test_tmp" },
    }

    service = ActiveStorage::Service.configure(:local, config)
    assert_match(/#<ActiveStorage::Service::DiskService name=:local>/, service.inspect)

    service = ActiveStorage::Service.new
    assert_match(/#<ActiveStorage::Service>/, service.inspect)
  end
end
