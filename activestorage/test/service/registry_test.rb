# frozen_string_literal: true

require "service/shared_service_tests"

class ActiveStorage::Service::RegistryTest < ActiveSupport::TestCase
  test "disallows access to service in incorrect environment" do
    assert_raise ActiveStorage::EnvironmentMismatchError do
      ActiveStorage::Service::Registry.new(foo: { service: "disk", environment: "production", root: "path" }).fetch(:foo)
    end
  end

  test "disallows access to service in incorrect environment with multiple environments listed" do
    assert_raise ActiveStorage::EnvironmentMismatchError do
      ActiveStorage::Service::Registry.new(foo: { service: "disk", environment: ["production", "staging"], root: "path" }).fetch(:foo)
    end
  end

  test "allows access to service in correct environment" do
    with_rails_env("production") do
      assert_nothing_raised do
        ActiveStorage::Service::Registry.new(foo: { service: "disk", environment: "production", root: "path" }).fetch(:foo)
        ActiveStorage::Service::Registry.new(foo: { service: "disk", environment: ["production", "staging"], root: "path" }).fetch(:foo)
        ActiveStorage::Service::Registry.new(foo: { service: "disk", environment: ["staging", "production"], root: "path" }).fetch(:foo)
      end
    end
  end

  test "allows access to service that doesn't restrict environment" do
    with_rails_env("production") do
      assert_nothing_raised do
        ActiveStorage::Service::Registry.new(foo: { service: "disk", environment: "", root: "path" }).fetch(:foo)
        ActiveStorage::Service::Registry.new(foo: { service: "disk", root: "path" }).fetch(:foo)
      end
    end
  end

  test "configures registry from config file" do
    with_rails_env("development") do
      configs = YAML.load(config_file_contents)
      registry = ActiveStorage::Service::Registry.new(configs)

      assert_raise ActiveStorage::EnvironmentMismatchError do
        registry.fetch(:amazon)
      end

      assert_nothing_raised do
        registry.fetch(:local)
      end
    end
  end

  private
    def with_rails_env(env)
      old_rails_env = Rails.env
      Rails.env = env
      yield
    ensure
      Rails.env = old_rails_env
    end

    def config_file_contents
      <<~YML
local:
  service: Disk
  root: "/tmp/foo"
  environment: development
amazon:
  service: S3
  bucket: foo
  region: us-east-1
  access_key_id: foo
  secret_access_key: bar
  environment:
    - production
    - staging
      YML
    end
end
