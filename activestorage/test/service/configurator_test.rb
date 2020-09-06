# frozen_string_literal: true

require 'service/shared_service_tests'

class ActiveStorage::Service::ConfiguratorTest < ActiveSupport::TestCase
  test 'builds correct service instance based on service name' do
    service = ActiveStorage::Service::Configurator.build(:foo, foo: { service: 'Disk', root: 'path' })
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal 'path', service.root
  end

  test 'builds correct service instance based on lowercase service name' do
    service = ActiveStorage::Service::Configurator.build(:foo, foo: { service: 'disk', root: 'path' })
    assert_instance_of ActiveStorage::Service::DiskService, service
    assert_equal 'path', service.root
  end

  test 'raises error when passing non-existent service name' do
    assert_raise RuntimeError do
      ActiveStorage::Service::Configurator.build(:bigfoot, {})
    end
  end
end
