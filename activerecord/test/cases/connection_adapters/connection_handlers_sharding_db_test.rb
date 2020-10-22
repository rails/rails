# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlersShardingDbTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      def setup
        @handlers = { writing: ConnectionHandler.new, reading: ConnectionHandler.new }
        @rw_handler = @handlers[:writing]
        @ro_handler = @handlers[:reading]
        @owner_name = "ActiveRecord::Base"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        @rw_pool = @handlers[:writing].establish_connection(db_config)
        @ro_pool = @handlers[:reading].establish_connection(db_config)
      end

      def teardown
        clean_up_connection_handler
      end

      unless in_memory_db?
        def test_establishing_a_connection_in_connected_to_block_uses_current_role_and_shard
          ActiveRecord::Base.connected_to(role: :writing, shard: :shard_one) do
            db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
            ActiveRecord::Base.establish_connection(db_config)
            assert_nothing_raised { Person.first }

            assert_equal [:default, :shard_one], ActiveRecord::Base.connection_handlers[:writing].send(:owner_to_pool_manager).fetch("ActiveRecord::Base").instance_variable_get(:@name_to_pool_config).keys
          end
        end

        def test_establish_connection_using_3_levels_config
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" },
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(shards: {
            default: { writing: :primary },
            shard_one: { writing: :primary_shard_one }
          })

          base_pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("ActiveRecord::Base")
          default_pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("ActiveRecord::Base", shard: :default)

          assert_equal base_pool, default_pool
          assert_equal "test/db/primary.sqlite3", default_pool.db_config.database
          assert_equal "primary", default_pool.db_config.name

          assert_not_nil pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("ActiveRecord::Base", shard: :shard_one)
          assert_equal "test/db/primary_shard_one.sqlite3", pool.db_config.database
          assert_equal "primary_shard_one", pool.db_config.name
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_establish_connection_using_3_levels_config_with_shards_and_replica
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true },
              "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" },
              "primary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3", "replica" => true }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(shards: {
            default: { writing: :primary, reading: :primary_replica },
            shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica }
          })

          default_writing_pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("ActiveRecord::Base", shard: :default)
          base_writing_pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("ActiveRecord::Base")
          assert_equal base_writing_pool, default_writing_pool
          assert_equal "test/db/primary.sqlite3", default_writing_pool.db_config.database
          assert_equal "primary", default_writing_pool.db_config.name

          default_reading_pool = ActiveRecord::Base.connection_handlers[:reading].retrieve_connection_pool("ActiveRecord::Base", shard: :default)
          base_reading_pool = ActiveRecord::Base.connection_handlers[:reading].retrieve_connection_pool("ActiveRecord::Base")
          assert_equal base_reading_pool, default_reading_pool
          assert_equal "test/db/primary.sqlite3", default_reading_pool.db_config.database
          assert_equal "primary_replica", default_reading_pool.db_config.name

          assert_not_nil pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("ActiveRecord::Base", shard: :shard_one)
          assert_equal "test/db/primary_shard_one.sqlite3", pool.db_config.database
          assert_equal "primary_shard_one", pool.db_config.name

          assert_not_nil pool = ActiveRecord::Base.connection_handlers[:reading].retrieve_connection_pool("ActiveRecord::Base", shard: :shard_one)
          assert_equal "test/db/primary_shard_one.sqlite3", pool.db_config.database
          assert_equal "primary_shard_one_replica", pool.db_config.name
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_via_handler
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true },
              "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" },
              "primary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3", "replica" => true }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(shards: {
            default: { writing: :primary, reading: :primary_replica },
            shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica }
          })

          ActiveRecord::Base.connected_to(role: :reading, shard: :default) do
            @ro_handler = ActiveRecord::Base.connection_handler
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:reading]
            assert_equal :reading, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :reading, shard: :default)
            assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :default)
            assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
            assert_not ActiveRecord::Base.connected_to?(role: :reading, shard: :shard_one)
            assert_predicate ActiveRecord::Base.connection, :preventing_writes?
          end

          ActiveRecord::Base.connected_to(role: :writing, shard: :default) do
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:writing]
            assert_not_equal @ro_handler, ActiveRecord::Base.connection_handler
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing, shard: :default)
            assert_not ActiveRecord::Base.connected_to?(role: :reading, shard: :default)
            assert_not ActiveRecord::Base.connected_to?(role: :reading, shard: :shard_one)
            assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
            assert_not_predicate ActiveRecord::Base.connection, :preventing_writes?
          end

          ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one) do
            @ro_handler = ActiveRecord::Base.connection_handler
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:reading]
            assert_equal :reading, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :reading, shard: :shard_one)
            assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
            assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :default)
            assert_not ActiveRecord::Base.connected_to?(role: :reading, shard: :default)
            assert_predicate ActiveRecord::Base.connection, :preventing_writes?
          end

          ActiveRecord::Base.connected_to(role: :writing, shard: :shard_one) do
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:writing]
            assert_not_equal @ro_handler, ActiveRecord::Base.connection_handler
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing, shard: :shard_one)
            assert_not ActiveRecord::Base.connected_to?(role: :reading, shard: :shard_one)
            assert_not ActiveRecord::Base.connected_to?(role: :reading, shard: :default)
            assert_not ActiveRecord::Base.connected_to?(role: :writing, shard: :default)
            assert_not_predicate ActiveRecord::Base.connection, :preventing_writes?
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_retrieves_proper_connection_with_nested_connected_to
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "primary_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true },
              "primary_shard_one" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3" },
              "primary_shard_one_replica" => { "adapter" => "sqlite3", "database" => "test/db/primary_shard_one.sqlite3", "replica" => true }
            }
          }

          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(shards: {
            default: { writing: :primary, reading: :primary_replica },
            shard_one: { writing: :primary_shard_one, reading: :primary_shard_one_replica }
          })

          ActiveRecord::Base.connected_to(role: :reading, shard: :shard_one) do
            # Uses the correct connection
            assert_equal "primary_shard_one_replica", ActiveRecord::Base.connection_pool.db_config.name

            # Uses the shard currently in use
            ActiveRecord::Base.connected_to(role: :writing) do
              assert_equal "primary_shard_one", ActiveRecord::Base.connection_pool.db_config.name
            end

            # Allows overriding the shard as well
            ActiveRecord::Base.connected_to(role: :reading, shard: :default) do
              assert_equal "primary_replica", ActiveRecord::Base.connection_pool.db_config.name
            end

            # Resets correctly
            assert_equal "primary_shard_one_replica", ActiveRecord::Base.connection_pool.db_config.name
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_connected_to_raises_without_a_shard_or_role
          error = assert_raises(ArgumentError) do
            ActiveRecord::Base.connected_to { }
          end
          assert_equal "must provide a `shard` and/or `role`.", error.message
        end

        def test_connects_to_raises_with_a_shard_and_database_key
          error = assert_raises(ArgumentError) do
            ActiveRecord::Base.connects_to(database: { writing: :arunit }, shards: { shard_one: { writing: :arunit } })
          end
          assert_equal "`connects_to` can only accept a `database` or `shards` argument, but not both arguments.", error.message
        end

        def test_retrieve_connection_pool_with_invalid_shard
          assert_not_nil @rw_handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_nil @rw_handler.retrieve_connection_pool("ActiveRecord::Base", shard: :foo)

          assert_not_nil @ro_handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_nil @ro_handler.retrieve_connection_pool("ActiveRecord::Base", shard: :foo)
        end

        def test_calling_connected_to_on_a_non_existent_shard_raises
          ActiveRecord::Base.connects_to(shards: {
            default: { writing: :arunit, reading: :arunit }
          })

          error = assert_raises ActiveRecord::ConnectionNotEstablished do
            ActiveRecord::Base.connected_to(role: :reading, shard: :foo) do
              Person.first
            end
          end

          assert_equal "No connection pool for 'ActiveRecord::Base' found for the 'foo' shard.", error.message
        end
      end

      class SecondaryBase < ActiveRecord::Base
        self.abstract_class = true
      end

      class ShardConnectionTestModel < SecondaryBase
      end

      class SomeOtherBase < ActiveRecord::Base
        self.abstract_class = true
      end

      class ShardConnectionTestModelB < SomeOtherBase
      end

      def test_same_shards_across_clusters
        SecondaryBase.connects_to shards: { one: { writing: { database: ":memory:", adapter: "sqlite3" } } }
        SomeOtherBase.connects_to shards: { one: { writing: { database: ":memory:", adapter: "sqlite3" } } }

        ActiveRecord::Base.connected_to(role: :writing, shard: :one) do
          ShardConnectionTestModel.connection.execute("CREATE TABLE `shard_connection_test_models` (shard_key VARCHAR (255))")
          ShardConnectionTestModel.create!(shard_key: "test_model_default")

          ShardConnectionTestModelB.connection.execute("CREATE TABLE `shard_connection_test_model_bs` (shard_key VARCHAR (255))")
          ShardConnectionTestModelB.create!(shard_key: "test_model_b_default")

          assert_equal "test_model_default", ShardConnectionTestModel.where(shard_key: "test_model_default").first.shard_key
          assert_equal "test_model_b_default", ShardConnectionTestModelB.where(shard_key: "test_model_b_default").first.shard_key
        end
      end

      def test_sharding_separation
        SecondaryBase.connects_to shards: {
          default: { writing: { database: ":memory:", adapter: "sqlite3" } },
          one: { writing: { database: ":memory:", adapter: "sqlite3" } }
        }

        [:default, :one].each do |shard_name|
          ActiveRecord::Base.connected_to(role: :writing, shard: shard_name) do
            ShardConnectionTestModel.connection.execute("CREATE TABLE `shard_connection_test_models` (shard_key VARCHAR (255))")
          end
        end

        # Create a record on :default
        ShardConnectionTestModel.create!(shard_key: "foo")

        # Make sure we can read it when explicitly connecting to :default
        ActiveRecord::Base.connected_to(role: :writing, shard: :default) do
          assert ShardConnectionTestModel.find_by_shard_key("foo")
        end

        # Switch to shard and make sure we can't read the record from :default
        # Also add a new record on :one
        ActiveRecord::Base.connected_to(role: :writing, shard: :one) do
          assert_not ShardConnectionTestModel.find_by_shard_key("foo")
          ShardConnectionTestModel.create!(shard_key: "bar")
        end

        # Make sure we can't read the record from :one but can read the record
        # from :default
        assert_not ShardConnectionTestModel.find_by_shard_key("bar")
        assert ShardConnectionTestModel.find_by_shard_key("foo")
      end

      def test_swapping_shards_in_a_multi_threaded_environment
        tf_default = Tempfile.open "shard_key_default"
        tf_shard_one = Tempfile.open "shard_key_one"

        SecondaryBase.connects_to shards: {
          default: { writing: { database: tf_default.path, adapter: "sqlite3" } },
          one: { writing: { database: tf_shard_one.path, adapter: "sqlite3" } }
        }

        [:default, :one].each do |shard_name|
          ActiveRecord::Base.connected_to(role: :writing, shard: shard_name) do
            ShardConnectionTestModel.connection.execute("CREATE TABLE `shard_connection_test_models` (shard_key VARCHAR (255))")
            ShardConnectionTestModel.connection.execute("INSERT INTO `shard_connection_test_models` VALUES ('shard_key_#{shard_name}')")
          end
        end

        shard_one_latch = Concurrent::CountDownLatch.new
        shard_default_latch = Concurrent::CountDownLatch.new

        ShardConnectionTestModel.connection

        thread = Thread.new do
          ShardConnectionTestModel.connection

          shard_default_latch.wait
          assert_equal "shard_key_default", ShardConnectionTestModel.connection.select_value("SELECT shard_key from shard_connection_test_models")
          shard_one_latch.count_down
        end

        ActiveRecord::Base.connected_to(role: :writing, shard: :one) do
          shard_default_latch.count_down
          assert_equal "shard_key_one", ShardConnectionTestModel.connection.select_value("SELECT shard_key from shard_connection_test_models")
          shard_one_latch.wait
        end

        thread.join
      ensure
        tf_shard_one.close
        tf_shard_one.unlink
        tf_default.close
        tf_default.unlink
      end

      def test_swapping_shards_and_roles_in_a_multi_threaded_environment
        tf_default = Tempfile.open "shard_key_default"
        tf_shard_one = Tempfile.open "shard_key_one"
        tf_default_reading = Tempfile.open "shard_key_default_reading"
        tf_shard_one_reading = Tempfile.open "shard_key_one_reading"

        SecondaryBase.connects_to shards: {
          default: { writing: { database: tf_default.path, adapter: "sqlite3" }, secondary: { database: tf_default_reading.path, adapter: "sqlite3" } },
          one: { writing: { database: tf_shard_one.path, adapter: "sqlite3" }, secondary: { database: tf_shard_one_reading.path, adapter: "sqlite3" } }
        }

        [:default, :one].each do |shard_name|
          ActiveRecord::Base.connected_to(role: :writing, shard: shard_name) do
            ShardConnectionTestModel.connection.execute("CREATE TABLE `shard_connection_test_models` (shard_key VARCHAR (255))")
            ShardConnectionTestModel.connection.execute("INSERT INTO `shard_connection_test_models` VALUES ('shard_key_#{shard_name}')")
          end

          ActiveRecord::Base.connected_to(role: :secondary, shard: shard_name) do
            ShardConnectionTestModel.connection.execute("CREATE TABLE `shard_connection_test_models` (shard_key VARCHAR (255))")
            ShardConnectionTestModel.connection.execute("INSERT INTO `shard_connection_test_models` VALUES ('shard_key_#{shard_name}_secondary')")
          end
        end

        shard_one_latch = Concurrent::CountDownLatch.new
        shard_default_latch = Concurrent::CountDownLatch.new

        ShardConnectionTestModel.connection

        thread = Thread.new do
          ShardConnectionTestModel.connection

          shard_default_latch.wait
          assert_equal "shard_key_default", ShardConnectionTestModel.connection.select_value("SELECT shard_key from shard_connection_test_models")
          shard_one_latch.count_down
        end

        ActiveRecord::Base.connected_to(shard: :one, role: :secondary) do
          shard_default_latch.count_down
          assert_equal "shard_key_one_secondary", ShardConnectionTestModel.connection.select_value("SELECT shard_key from shard_connection_test_models")
          shard_one_latch.wait
        end

        thread.join
      ensure
        tf_shard_one.close
        tf_shard_one.unlink
        tf_default.close
        tf_default.unlink
        tf_shard_one_reading.close
        tf_shard_one_reading.unlink
        tf_default_reading.close
        tf_default_reading.unlink
      end
    end
  end
end
