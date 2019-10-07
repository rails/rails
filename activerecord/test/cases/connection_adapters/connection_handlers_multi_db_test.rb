# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlersMultiDbTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      def setup
        @handlers = { "Base" => ConnectionHandler.new, "Animal" => ConnectionHandler.new }
        @primary_handler = @handlers["Base"]
        @animals_handler = @handlers["Animal"]
        @rw_pool = @handlers["Base"].establish_connection(ActiveRecord::Base.configurations["arunit"], role: :writing)
        @ro_pool = @handlers["Animal"].establish_connection(ActiveRecord::Base.configurations["arunit"], role: :reading)
      end

      def teardown
        ActiveRecord::Base.connection_handlers = { "ActiveRecord::Base" => ActiveRecord::Base.default_connection_handler }
      end

      class MultiConnectionTestModel < ActiveRecord::Base
      end

      def test_multiple_connection_handlers_works_in_a_threaded_environment
        tf_writing = Tempfile.open "test_writing"
        tf_reading = Tempfile.open "test_reading"

        MultiConnectionTestModel.connects_to database: { writing: { database: tf_writing.path, adapter: "sqlite3" }, reading: { database: tf_reading.path, adapter: "sqlite3" } }

        MultiConnectionTestModel.connection.execute("CREATE TABLE `test_1` (connection_role VARCHAR (255))")
        MultiConnectionTestModel.connection.execute("INSERT INTO test_1 VALUES ('writing')")

        ActiveRecord::Base.connected_to(role: :reading) do
          MultiConnectionTestModel.connection.execute("CREATE TABLE `test_1` (connection_role VARCHAR (255))")
          MultiConnectionTestModel.connection.execute("INSERT INTO test_1 VALUES ('reading')")
        end

        read_latch = Concurrent::CountDownLatch.new
        write_latch = Concurrent::CountDownLatch.new

        MultiConnectionTestModel.connection

        thread = Thread.new do
          MultiConnectionTestModel.connection

          write_latch.wait
          assert_equal "writing", MultiConnectionTestModel.connection.select_value("SELECT connection_role from test_1")
          read_latch.count_down
        end

        ActiveRecord::Base.connected_to(role: :reading) do
          write_latch.count_down
          assert_equal "reading", MultiConnectionTestModel.connection.select_value("SELECT connection_role from test_1")
          read_latch.wait
        end

        thread.join
      ensure
        tf_reading.close
        tf_reading.unlink
        tf_writing.close
        tf_writing.unlink
      end

      unless in_memory_db?
        def test_establish_connection_using_3_levels_config
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3", "replica" => true },
              "default"  => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :default, reading: :readonly })

          assert_not_nil pool = ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:writing)
          assert_equal "db/primary.sqlite3", pool.db_config.database
          assert_equal "default", pool.db_config.spec_name

          assert_not_nil pool = ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:reading)
          assert_equal "db/readonly.sqlite3", pool.db_config.database
          assert_equal "readonly", pool.db_config.spec_name
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_via_handler
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" },
              "primary"  => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :readonly })

          ActiveRecord::Base.connected_to(role: :reading) do
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]
            assert_equal :reading, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :reading)
            assert_not ActiveRecord::Base.connected_to?(role: :writing)
          end

          ActiveRecord::Base.connected_to(role: :writing) do
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing)
            assert_not ActiveRecord::Base.connected_to?(role: :reading)
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
              "readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" },
              "primary"  => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { default: :primary, readonly: :readonly })

          assert_not_nil pool = ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:default)
          assert_equal "db/primary.sqlite3", pool.db_config.database

          assert_not_nil pool = ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:readonly)
          assert_equal "db/readonly.sqlite3", pool.db_config.database
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_with_database_url
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"
          previous_url, ENV["DATABASE_URL"] = ENV["DATABASE_URL"], "postgres://localhost/foo"

          ActiveRecord::Base.connected_to(database: { writing: "postgres://localhost/bar" }) do
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing)

            handler = ActiveRecord::Base.connection_handler
            assert_equal handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]

            assert_not_nil pool = handler.retrieve_connection_pool(:writing)
            assert_equal({ adapter: "postgresql", database: "bar", host: "localhost" }, pool.db_config.configuration_hash)
          end
        ensure
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
          ENV["DATABASE_URL"] = previous_url
        end

        def test_switching_connections_with_database_config_hash
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"
          config = { adapter: "sqlite3", database: "db/readonly.sqlite3" }

          ActiveRecord::Base.connected_to(database: { writing: config }) do
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing)

            handler = ActiveRecord::Base.connection_handler
            assert_equal handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]

            assert_not_nil pool = handler.retrieve_connection_pool(:writing)
            assert_equal(config, pool.db_config.configuration_hash)
          end
        ensure
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_with_database_and_role_raises
          error = assert_raises(ArgumentError) do
            ActiveRecord::Base.connected_to(database: :readonly, role: :writing) { }
          end
          assert_equal "connected_to can only accept a `database` or a `role` argument, but not both arguments.", error.message
        end

        def test_switching_connections_without_database_and_role_raises
          error = assert_raises(ArgumentError) do
            ActiveRecord::Base.connected_to { }
          end
          assert_equal "must provide a `database` or a `role`.", error.message
        end

        def test_switching_connections_with_database_symbol_uses_default_role
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "animals" => { adapter: "sqlite3", database: "db/animals.sqlite3" },
              "primary" => { adapter: "sqlite3", database: "db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connected_to(database: :animals) do
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing)

            handler = ActiveRecord::Base.connection_handler
            assert_equal handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]

            assert_not_nil pool = handler.retrieve_connection_pool(:writing)
            assert_equal(config["default_env"]["animals"], pool.db_config.configuration_hash)
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_switching_connections_with_database_hash_uses_passed_role_and_database
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "animals" => { adapter: "sqlite3", database: "db/animals.sqlite3" },
              "primary" => { adapter: "sqlite3", database: "db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connected_to(database: { writing: :primary }) do
            assert_equal :writing, ActiveRecord::Base.current_role
            assert ActiveRecord::Base.connected_to?(role: :writing)

            handler = ActiveRecord::Base.connection_handler
            assert_equal handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]

            assert_not_nil pool = handler.retrieve_connection_pool(:writing)
            assert_equal(config["default_env"]["primary"], pool.db_config.configuration_hash)
          end
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ENV["RAILS_ENV"] = previous_env
        end

        def test_connects_to_with_single_configuration
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" },
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config
          @previous_connection_handlers = ActiveRecord::Base.connection_handlers
          ActiveRecord::Base.connection_handlers = {}

          ActiveRecord::Base.connects_to database: { writing: :development }

          assert_equal 1, ActiveRecord::Base.connection_handlers.size
          assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers["ActiveRecord::Base"]
          assert_equal :writing, ActiveRecord::Base.current_role
          assert ActiveRecord::Base.connected_to?(role: :writing)
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
          ActiveRecord::Base.connection_handlers = @previous_connection_handlers
        end

        def test_connects_to_using_top_level_key_in_two_level_config
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" },
            "development_readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to database: { writing: :development, reading: :development_readonly }

          assert_not_nil pool = ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:writing)
          assert_equal "db/primary.sqlite3", pool.db_config.database
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end

        def test_connects_to_returns_array_of_established_connections
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" },
            "development_readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          result = ActiveRecord::Base.connects_to database: { writing: :development, reading: :development_readonly }

          assert_equal(
            [
              ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:writing),
              ActiveRecord::Base.connection_handlers["ActiveRecord::Base"].retrieve_connection_pool(:reading)
            ],
            result
          )
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end
      end

      def test_connection_pools
        assert_equal([@rw_pool], @handlers["Base"].connection_pools)
        assert_equal([@ro_pool], @handlers["Animal"].connection_pools)
      end

      def test_retrieve_connection
        assert @primary_handler.retrieve_connection(:writing)
        assert @animals_handler.retrieve_connection(:reading)
      end

      def test_active_connections
        assert_not_predicate @primary_handler, :active_connections?
        assert_not_predicate @animals_handler, :active_connections?

        assert @primary_handler.retrieve_connection(:writing)
        assert @animals_handler.retrieve_connection(:reading)

        assert_predicate @primary_handler, :active_connections?
        assert_predicate @animals_handler, :active_connections?

        @primary_handler.clear_active_connections!
        assert_not_predicate @primary_handler, :active_connections?

        @animals_handler.clear_active_connections!
        assert_not_predicate @animals_handler, :active_connections?
      end

      def test_retrieve_connection_pool
        assert_not_nil @primary_handler.retrieve_connection_pool(:writing)
        assert_not_nil @animals_handler.retrieve_connection_pool(:reading)
      end

      def test_retrieve_connection_pool_with_invalid_id
        assert_nil @primary_handler.retrieve_connection_pool("foo")
        assert_nil @animals_handler.retrieve_connection_pool("foo")
      end

      def test_connection_role_are_per_thread_and_not_per_fiber
        reading = Person.connected_to(role: :reading) do
          Person.connection_handler.current_role
        end

        assert_not_equal reading, ActiveRecord::Base.connection_handler.current_role
        assert_equal Person.current_role, ActiveRecord::Base.current_role
      end

      def test_connection_handlers_swapping_connections_in_fiber
        enum = Enumerator.new do |r|
          r << ActiveRecord::Base.current_role
        end

        reading_role = ActiveRecord::Base.connected_to(role: :reading) do
          enum.next
        end

        assert_equal :reading, reading_role
      end

      def test_calling_connected_to_on_a_non_existent_handler_raises
        klassA = Class.new(ActiveRecord::Base) do
          def self.name
            "KlassA"
          end
        end

        klassB = Class.new(klassA) do
          def self.name
            "KlassB"
          end
        end

        klassA.establish_connection(ActiveRecord::Base.configurations["arunit2"])
        error = assert_raises ActiveRecord::ConnectionNotEstablished do
          klassA.connected_to(role: :some_role) do
            klassB.first
          end
        end

        database_name = klassA.connection_config[:database]

        assert_equal "No connection pool for 'some_role' role found for the '#{database_name}' database.", error.message
      end

      def test_default_handlers_are_writing_and_reading
        assert_equal :writing, ActiveRecord::Base.writing_role
        assert_equal :reading, ActiveRecord::Base.reading_role
      end

      def test_an_application_can_change_the_default_handlers
        old_writing = ActiveRecord::Base.writing_role
        old_reading = ActiveRecord::Base.reading_role
        ActiveRecord::Base.writing_role = :default
        ActiveRecord::Base.reading_role = :readonly

        assert_equal :default, ActiveRecord::Base.writing_role
        assert_equal :readonly, ActiveRecord::Base.reading_role
      ensure
        ActiveRecord::Base.writing_role = old_writing
        ActiveRecord::Base.reading_role = old_reading
      end
    end
  end
end
