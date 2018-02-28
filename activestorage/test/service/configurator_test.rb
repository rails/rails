# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::ConfiguratorTest < ActiveSupport::TestCase
  test "builds correct service instance based on service name" do
    configs = <<-YAML.strip_heredoc
      foo:
        service: Disk
        root: path
        host: https://example.com
    YAML

    service = ActiveStorage::Service::Configurator.build(:foo, YAML.load(configs))

    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal "path", service.root
    assert_equal "https://example.com", service.host
  end

  test "raises error when passing non-existent service name" do
    assert_raise RuntimeError do
      ActiveStorage::Service::Configurator.build(:bigfoot, {})
    end
  end
end
