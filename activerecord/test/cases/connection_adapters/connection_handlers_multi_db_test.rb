# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlersMultiDbTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      def setup
        @handler = ConnectionHandler.new
        @owner_name = "ActiveRecord::Base"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        @rw_pool = @handler.establish_connection(db_config)
        @ro_pool = @handler.establish_connection(db_config, role: :reading)
      end

      def teardown
        clean_up_connection_handler
      end

      class SecondaryBase < ActiveRecord::Base
        self.abstract_class = true
      end

      class MultiConnectionTestModel < SecondaryBase
      end

      def test_multiple_connections_works_in_a_threaded_environment
        tf_writing = Tempfile.open "test_writing"
        tf_reading = Tempfile.open "test_reading"

        # We need to use a role for reading not named reading, otherwise we'll prevent writes
        # and won't be able to write to the second connection.
        SecondaryBase.connects_to database: { writing: { database: tf_writing.path, adapter: "sqlite3" }, secondary: { database: tf_reading.path, adapter: "sqlite3" } }

        MultiConnectionTestModel.connection.execute("CREATE TABLE `multi_connection_test_models` (connection_role VARCHAR (255))")
        MultiConnectionTestModel.connection.execute("INSERT INTO multi_connection_test_models VALUES ('writing')")

        ActiveRecord::Base.connected_to(role: :secondary) do
          MultiConnectionTestModel.connection.execute("CREATE TABLE `multi_connection_test_models` (connection_role VARCHAR (255))")
          MultiConnectionTestModel.connection.execute("INSERT INTO multi_connection_test_models VALUES ('reading')")
        end

        read_latch = Concurrent::CountDownLatch.new
        write_latch = Concurrent::CountDownLatch.new

        MultiConnectionTestModel.connection

        thread = Thread.new do
          MultiConnectionTestModel.connection

          write_latch.wait
          assert_equal "writing", MultiConnectionTestModel.connection.select_value("SELECT connection_role from multi_connection_test_models")
          read_latch.count_down
        end

        ActiveRecord::Base.connected_to(role: :secondary) do
          write_latch.count_down
          assert_equal "reading", MultiConnectionTestModel.connection.select_value("SELECT connection_role from multi_connection_test_models")
          read_latch.wait
        end

        thread.join
      ensure
        tf_reading.close
        tf_reading.unlink
        tf_writing.close
        tf_writing.unlink
      end

      def test_loading_relations_with_multi_db_connections
        # We need to use a role for reading not named reading, otherwise we'll prevent writes
        # and won't be able to write to the second connection.
        SecondaryBase.connects_to database: { writing: { database: ":memory:", adapter: "sqlite3" }, secondary: { database: ":memory:", adapter: "sqlite3" } }

        relation = ActiveRecord::Base.connected_to(role: :secondary) do
          MultiConnectionTestModel.connection.execute("CREATE TABLE `multi_connection_test_models` (connection_role VARCHAR (255))")
          MultiConnectionTestModel.create!(connection_role: "reading")
          MultiConnectionTestModel.where(connection_role: "reading")
        end

        assert_equal "reading", relation.first.connection_role
      end

      unless in_memory_db?
        def test_establish_connection_using_3_levels_config
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3", "replica" => true },
              "default"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :default, reading: :readonly })

          assert_not_nil pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal "test/db/primary.sqlite3", pool.db_config.database
          assert_equal "default", pool.db_config.name

          assert_not_nil pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading)
          assert_equal "test/db/readonly.sqlite3", pool.db_config.database
          assert_equal "readonly", pool.db_config.name
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_via_handler
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" },
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :readonly })

          ActiveRecord::Base.connected_to(role: :reading) do
            assert_equal :reading, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :reading)
            assert_not ActiveRecord::Base.connected_to?(role: :writing)
            assert_predicate ActiveRecord::Base.connection, :preventing_writes?
          end

          ActiveRecord::Base.connected_to(role: :writing) do
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing)
            assert_not ActiveRecord::Base.connected_to?(role: :reading)
            assert_not_predicate ActiveRecord::Base.connection, :preventing_writes?
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_establish_connection_using_3_levels_config_with_non_default_handlers
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" },
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { default: :primary, readonly: :readonly })

          assert_not_nil pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base", role: :default)
          assert_equal "test/db/primary.sqlite3", pool.db_config.database

          assert_not_nil pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base", role: :readonly)
          assert_equal "test/db/readonly.sqlite3", pool.db_config.database
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_with_database_url
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"
          previous_url, ENV["DATABASE_URL"] = ENV["DATABASE_URL"], "postgres://localhost/foo"

          ActiveRecord::Base.connects_to(database: { writing: "postgres://localhost/bar" })
          assert_equal :writing, ActiveRecord::Base.current_role
          assert ActiveRecord::Base.connected_to?(role: :writing)

          handler = ActiveRecord::Base.connection_handler
          assert_equal handler, ActiveRecord::Base.connection_handler

          assert_not_nil pool = handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal({ adapter: "postgresql", database: "bar", host: "localhost" }, pool.db_config.configuration_hash)
        ensure
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
          ENV["DATABASE_URL"] = previous_url
        end

        def test_switching_connections_with_database_config_hash
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"
          config = { adapter: "sqlite3", database: "test/db/readonly.sqlite3" }

          ActiveRecord::Base.connects_to(database: { writing: config })
          assert_equal :writing, ActiveRecord::Base.current_role
          assert ActiveRecord::Base.connected_to?(role: :writing)

          handler = ActiveRecord::Base.connection_handler
          assert_equal handler, ActiveRecord::Base.connection_handler

          assert_not_nil pool = handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal(config, pool.db_config.configuration_hash)
        ensure
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_without_database_and_role_raises
          error = assert_raises(ArgumentError) do
            ActiveRecord::Base.connected_to { }
          end
          assert_equal "must provide a `shard` and/or `role`.", error.message
        end

        def test_switching_connections_with_database_symbol_uses_default_role
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "animals" => { adapter: "sqlite3", database: "test/db/animals.sqlite3" },
              "primary" => { adapter: "sqlite3", database: "test/db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :animals })
          assert_equal :writing, ActiveRecord::Base.current_role
          assert ActiveRecord::Base.connected_to?(role: :writing)

          handler = ActiveRecord::Base.connection_handler
          assert_equal handler, ActiveRecord::Base.connection_handler

          assert_not_nil pool = handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal(config["default_env"]["animals"], pool.db_config.configuration_hash)
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_with_database_hash_uses_passed_role_and_database
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "animals" => { adapter: "sqlite3", database: "test/db/animals.sqlite3" },
              "primary" => { adapter: "sqlite3", database: "test/db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :primary })
          assert_equal :writing, ActiveRecord::Base.current_role
          assert ActiveRecord::Base.connected_to?(role: :writing)

          handler = ActiveRecord::Base.connection_handler
          assert_equal handler, ActiveRecord::Base.connection_handler

          assert_not_nil pool = handler.retrieve_connection_pool("ActiveRecord::Base")
          assert_equal(config["default_env"]["primary"], pool.db_config.configuration_hash)
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_connects_to_with_single_configuration
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to database: { writing: :development }

          assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handler
          assert_equal :writing, ActiveRecord::Base.current_role
          assert ActiveRecord::Base.connected_to?(role: :writing)
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end

        def test_connects_to_using_top_level_key_in_two_level_config
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
            "development_readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to database: { writing: :development, reading: :development_readonly }

          assert_not_nil pool = ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading)
          assert_equal "test/db/readonly.sqlite3", pool.db_config.database
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end

        def test_connects_to_returns_array_of_established_connections
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
            "development_readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          result = ActiveRecord::Base.connects_to database: { writing: :development, reading: :development_readonly }

          assert_equal(
            [
              ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base"),
              ActiveRecord::Base.connection_handler.retrieve_connection_pool("ActiveRecord::Base", role: :reading)
            ],
            result
          )
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end
      end

      def test_connection_pools
        assert_equal([@rw_pool], @handler.connection_pools(:writing))
        assert_equal([@ro_pool], @handler.connection_pools(:reading))
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@owner_name)
        assert @handler.retrieve_connection(@owner_name, role: :reading)
      end

      def test_active_connections?
        assert_not_predicate @handler, :active_connections?

        assert @handler.retrieve_connection(@owner_name)
        assert @handler.retrieve_connection(@owner_name, role: :reading)

        assert_predicate @handler, :active_connections?

        @handler.clear_active_connections!
        assert_not_predicate @handler, :active_connections?
      end

      def test_retrieve_connection_pool
        assert_not_nil @handler.retrieve_connection_pool(@owner_name)
        assert_not_nil @handler.retrieve_connection_pool(@owner_name, role: :reading)
      end

      def test_retrieve_connection_pool_with_invalid_id
        assert_nil @handler.retrieve_connection_pool("foo")
        assert_nil @handler.retrieve_connection_pool("foo", role: :reading)
      end

      def test_calling_connected_to_on_a_non_existent_handler_raises
        error = assert_raises ActiveRecord::ConnectionNotEstablished do
          ActiveRecord::Base.connected_to(role: :non_existent) do
            Person.first
          end
        end

        assert_equal "No connection pool for 'ActiveRecord::Base' found for the 'non_existent' role.", error.message
      end

      def test_default_handlers_are_writing_and_reading
        assert_equal :writing, ActiveRecord.writing_role
        assert_equal :reading, ActiveRecord.reading_role
      end

      def test_an_application_can_change_the_default_handlers
        old_writing = ActiveRecord.writing_role
        old_reading = ActiveRecord.reading_role
        ActiveRecord.writing_role = :default
        ActiveRecord.reading_role = :readonly

        assert_equal :default, ActiveRecord.writing_role
        assert_equal :readonly, ActiveRecord.reading_role
      ensure
        ActiveRecord.writing_role = old_writing
        ActiveRecord.reading_role = old_reading
      end
    end
  end
end
