# frozen_string_literal: true

require "test_helper"
require_relative "fixtures/active_storage/in_memory_backend"

class ActiveStorage::ServicesTest < ActiveSupport::TestCase
  setup do
    @registry = ActiveStorage::Services.registry
    @default = ActiveStorage::Services.default
  end

  teardown do
    ActiveStorage::Services.registry = @registry
    ActiveStorage::Services.default = @default
  end

  test "blob service access reports missing service initialization" do
    blob = ActiveStorage::InMemoryBackend::Blob.new(service_name: :local)
    ActiveStorage::Services.registry = nil

    assert_not ActiveStorage::Services.configured?
    assert_raises(ActiveStorage::ConfigurationError) { ActiveStorage::Services.registry }
    assert_raises(ActiveStorage::ConfigurationError) { ActiveStorage::Services.default }
    assert_raises(ActiveStorage::ConfigurationError) { ActiveStorage::Services.fetch(:local) }
    assert_raises(ActiveStorage::ConfigurationError) { ActiveStorage::InMemoryBackend::Blob.services.fetch(:local) }
    assert_raises(ActiveStorage::ConfigurationError) { ActiveStorage::InMemoryBackend::Blob.service }
    assert_raises(ActiveStorage::ConfigurationError) { blob.service_url_for_direct_upload }
    assert_raises(ActiveStorage::ConfigurationError) { blob.service_headers_for_direct_upload }
    assert_raises(ActiveStorage::ConfigurationError) { blob.download }
  end

  test "an empty registry is configured and can have no default service" do
    ActiveStorage::Services.registry = ActiveStorage::Service::Registry.new({})
    ActiveStorage::Services.default = nil

    assert ActiveStorage::Services.configured?
    assert_nil ActiveStorage::Services.default
    assert_nil ActiveStorage::InMemoryBackend::Blob.service
    assert_raises(KeyError) { ActiveStorage::Services.fetch(:missing) }
    assert_equal :fallback, ActiveStorage::Services.fetch(:missing) { :fallback }
    assert_equal :fallback, ActiveStorage::InMemoryBackend::Blob.services.fetch(:missing) { :fallback }
  end

  test "configured blob readers expose the selected services" do
    assert ActiveStorage::Services.configured?
    assert_same @registry, ActiveStorage::InMemoryBackend::Blob.services
    assert_same @default, ActiveStorage::InMemoryBackend::Blob.service
    assert_same @default, ActiveStorage::Services.fetch(@default.name)
  end
end
