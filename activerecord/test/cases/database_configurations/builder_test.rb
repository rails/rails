# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  class DatabaseConfigurations
    class BuilderTest < ActiveRecord::TestCase
      setup do
        ActiveRecord::DatabaseConfigurations.builder = ActiveRecord::DatabaseConfigurations::Builder.new
      end

      teardown do
        ActiveRecord::DatabaseConfigurations.builder = nil
      end

      def test_can_create_basic_configuration
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              adapter "sqlite3"
              database "test/db/primary.sqlite3"
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3" }, config.configuration_hash)
      end

      def test_can_create_basic_replica_configuration
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              adapter "sqlite3"
              database "test/db/primary.sqlite3"

              replica
            end
          end
        end

        assert_equal 2, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_not_predicate config, :replica?
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3" }, config.configuration_hash)

        config = configs.last
        assert_equal "development", config.env_name
        assert_equal "primary_replica", config.name
        assert_predicate config, :replica?
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", replica: true }, config.configuration_hash)
      end

      def test_can_merge_default_configuration
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
            database "test/db/primary.sqlite3"
          end

          env(:development) do
            config(:primary, default) do
              pool 5
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", pool: 5 }, config.configuration_hash)
      end

      def test_can_merge_default_configuration_for_multiple_configurations
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
          end

          env(:development) do
            config(:primary, default) do
              database "test/db/primary.sqlite3"
              pool 5

              replica do
                database "test/db/readonly.sqlite3"
                random 10
              end
            end
          end
        end

        assert_equal 2, configs.length

        config_a = configs.first
        assert_equal "development", config_a.env_name
        assert_equal "primary", config_a.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", pool: 5 }, config_a.configuration_hash)

        config_b = configs.last
        assert_equal "development", config_b.env_name
        assert_equal "primary_replica", config_b.name
        assert_predicate config_b, :replica?
        assert_equal({ adapter: "sqlite3", database: "test/db/readonly.sqlite3", replica: true, random: 10, pool: 5 }, config_b.configuration_hash)
      end

      def test_can_merge_default_configurations_for_multiple_configurations
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
            database "test/db/primary.sqlite3"
          end

          default_other = build do
            adapter "sqlite3"
            database "test/db/other.sqlite3"
          end

          env(:development) do
            config(:primary, default) do
              pool 5
            end

            config(:other, default_other) do
              random 10
            end
          end
        end

        assert_equal 2, configs.length

        config_a = configs.first
        assert_equal "development", config_a.env_name
        assert_equal "primary", config_a.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", pool: 5 }, config_a.configuration_hash)

        config_b = configs.last
        assert_equal "development", config_b.env_name
        assert_equal "other", config_b.name
        assert_equal({ adapter: "sqlite3", database: "test/db/other.sqlite3", random: 10 }, config_b.configuration_hash)
      end

      def test_can_base_default_on_another_default
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
          end

          default_other = build(default) do
            database "test/db/other.sqlite3"
          end

          env(:development) do
            config(:primary, default_other) do
              pool 5
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ adapter: "sqlite3", database: "test/db/other.sqlite3", pool: 5 }, config.configuration_hash)
      end

      def test_can_override_default_in_another_default
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
            database "test/db/primary.sqlite3"
          end

          default_other = build(default) do
            database "test/db/other.sqlite3"
          end

          env(:development) do
            config(:primary, default_other) do
              pool 5
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ adapter: "sqlite3", database: "test/db/other.sqlite3", pool: 5 }, config.configuration_hash)
      end

      def test_can_override_default_in_config
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
            database "test/db/primary.sqlite3"
          end

          env(:development) do
            config(:primary, default) do
              database "test/db/other.sqlite3"
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ adapter: "sqlite3", database: "test/db/other.sqlite3" }, config.configuration_hash)
      end

      def test_can_create_configs_for_multiple_envs
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
            database "test/db/primary.sqlite3"
          end

          env(:development) do
            config(:primary, default) do
              pool 5
            end
          end

          env(:test) do
            config(:primary, default) do
              random 10
            end
          end
        end

        assert_equal 2, configs.length

        config_dev = configs.first
        assert_equal "development", config_dev.env_name
        assert_equal "primary", config_dev.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", pool: 5 }, config_dev.configuration_hash)

        config_test = configs.last
        assert_equal "test", config_test.env_name
        assert_equal "primary", config_test.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", random: 10 }, config_test.configuration_hash)
      end

      def test_can_support_nested_hashes
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            adapter "sqlite3"
            database "test/db/primary.sqlite3"
          end

          env(:development) do
            config(:primary, default) do
              properties({ a: "a", b: "b" })
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ adapter: "sqlite3", database: "test/db/primary.sqlite3", properties: { a: "a", b: "b" } }, config.configuration_hash)
      end

      def test_creates_url_configs_when_url_key_provided
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              url "sqlite3:///foo_test"
              pool 5
            end
          end
        end

        assert_equal 1, configs.length

        config = configs.first
        assert_equal "development", config.env_name
        assert_equal "primary", config.name
        assert_equal({ pool: 5, adapter: "sqlite3", database: "/foo_test" }, config.configuration_hash)
      end

      def test_can_config_multiple_named_replicas
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              database "test/db/primary.sqlite3"

              replica(:one)
              replica(:two)
            end
          end
        end

        assert_equal ["primary", "primary_replica_one", "primary_replica_two"], configs.map(&:name).sort
      end

      def test_order_of_overrides
        configs = ActiveRecord::DatabaseConfigurations.configure do
          default = build do
            default true
            default_replica false
            primary false
            replicas false
          end

          default_replica = build do
            default_replica true
            replicas false
          end

          env(:development) do
            # primary can override default
            config(:primary, default) do
              primary true
              default_replica false
              replicas false

              # :replica_one inherits from primary, can override primary
              replica(:one) do
                replicas true
              end

              # :replica_two inherits from primary, overrides anything in
              # primary from default_replica, can also override in
              # the block.
              replica(:two, default_replica) do
                replicas true
              end
            end
          end
        end

        assert_equal [
          { default: true, default_replica: false, primary: true, replicas: false },
          { default: true, default_replica: false, primary: true, replicas: true, replica: true },
          { default: true, default_replica: true, primary: true, replicas: true, replica: true }
        ], configs.map(&:configuration_hash)
      end

      def test_using_ruby_in_blocks_to_generate_configs
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              2.times do |i|
                replica(:"replica_#{i}")
              end
            end
          end
        end

        assert_equal 3, configs.count
      end

      def test_using_shard
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              database "default_development"
              pool 5

              shard(:one) do
                database "shard_one_development"
              end
            end
          end
        end

        assert_equal ["primary", "primary_shard_one"], configs.map(&:name)

        assert_equal [
          { database: "default_development", pool: 5 },
          { database: "shard_one_development", pool: 5 }
        ], configs.map(&:configuration_hash)
      end

      def test_using_shard_with_nested_replica
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              database "default_development"
              pool 5
              replica

              shard(:one) do
                database "shard_one_development"
                replica
              end
            end
          end
        end

        assert_equal ["primary", "primary_replica", "primary_shard_one", "primary_shard_one_replica"], configs.map(&:name)

        assert_equal [
          { database: "default_development", pool: 5 },
          { database: "default_development", pool: 5, replica: true },
          { database: "shard_one_development", pool: 5 },
          { database: "shard_one_development", pool: 5, replica: true }
        ], configs.map(&:configuration_hash)
      end

      def test_using_shard_with_additional_properties
        configs = ActiveRecord::DatabaseConfigurations.configure do
          env(:development) do
            config(:primary) do
              database "default_development"
              pool 5

              shard(:one) do
                database "shard_one_development"
                pool 10
                username "toor"
              end
            end
          end
        end

        assert_equal ["primary", "primary_shard_one"], configs.map(&:name)

        assert_equal [
          { database: "default_development", pool: 5 },
          { database: "shard_one_development", pool: 10, username: "toor" },
        ], configs.map(&:configuration_hash)
      end

      def test_using_shard_with_defaults
        configs = ActiveRecord::DatabaseConfigurations.configure do
          shard_default = build do
            sharded true
          end

          env(:development) do
            config(:primary) do
              database "default_development"

              shard(:one, shard_default) do
                database "shard_one_development"
              end
            end
          end
        end

        assert_equal ["primary", "primary_shard_one"], configs.map(&:name)

        assert_equal [
          { database: "default_development" },
          { database: "shard_one_development", sharded: true }
        ], configs.map(&:configuration_hash)
      end
    end
  end
end
