# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlersMultiDbTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      fixtures :people

      def setup
        @handlers = { writing: ConnectionHandler.new, reading: ConnectionHandler.new }
        @rw_handler = @handlers[:writing]
        @ro_handler = @handlers[:reading]
        @spec_name = "primary"
        @rw_pool = @handlers[:writing].establish_connection(ActiveRecord::Base.configurations["arunit"])
        @ro_pool = @handlers[:reading].establish_connection(ActiveRecord::Base.configurations["arunit"])
      end

      def teardown
        ActiveRecord::Base.connection_handlers = { writing: ActiveRecord::Base.default_connection_handler }
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
              "readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" },
              "primary"  => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to(database: { writing: :primary, reading: :readonly })

          assert_not_nil pool = ActiveRecord::Base.connection_handlers[:writing].retrieve_connection_pool("primary")
          assert_equal "db/primary.sqlite3", pool.spec.config[:database]

          assert_not_nil pool = ActiveRecord::Base.connection_handlers[:reading].retrieve_connection_pool("primary")
          assert_equal "db/readonly.sqlite3", pool.spec.config[:database]
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
            @ro_handler = ActiveRecord::Base.connection_handler
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:reading]
          end

          ActiveRecord::Base.connected_to(role: :writing) do
            assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:writing]
            assert_not_equal @ro_handler, ActiveRecord::Base.connection_handler
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

          ActiveRecord::Base.connects_to database: { writing: :development }

          assert_equal 1, ActiveRecord::Base.connection_handlers.size
          assert_equal ActiveRecord::Base.connection_handler, ActiveRecord::Base.connection_handlers[:writing]
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end

        def test_connects_to_using_top_level_key_in_two_level_config
          config = {
            "development" => { "adapter" => "sqlite3", "database" => "db/primary.sqlite3" },
            "development_readonly" => { "adapter" => "sqlite3", "database" => "db/readonly.sqlite3" }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.connects_to database: { writing: :development, reading: :development_readonly }

          assert_not_nil pool = ActiveRecord::Base.connection_handlers[:reading].retrieve_connection_pool("primary")
          assert_equal "db/readonly.sqlite3", pool.spec.config[:database]
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ActiveRecord::Base.establish_connection(:arunit)
        end
      end

      def test_connection_pools
        assert_equal([@rw_pool], @handlers[:writing].connection_pools)
        assert_equal([@ro_pool], @handlers[:reading].connection_pools)
      end

      def test_retrieve_connection
        assert @rw_handler.retrieve_connection(@spec_name)
        assert @ro_handler.retrieve_connection(@spec_name)
      end

      def test_active_connections?
        assert_not_predicate @rw_handler, :active_connections?
        assert_not_predicate @ro_handler, :active_connections?

        assert @rw_handler.retrieve_connection(@spec_name)
        assert @ro_handler.retrieve_connection(@spec_name)

        assert_predicate @rw_handler, :active_connections?
        assert_predicate @ro_handler, :active_connections?

        @rw_handler.clear_active_connections!
        assert_not_predicate @rw_handler, :active_connections?

        @ro_handler.clear_active_connections!
        assert_not_predicate @ro_handler, :active_connections?
      end

      def test_retrieve_connection_pool
        assert_not_nil @rw_handler.retrieve_connection_pool(@spec_name)
        assert_not_nil @ro_handler.retrieve_connection_pool(@spec_name)
      end

      def test_retrieve_connection_pool_with_invalid_id
        assert_nil @rw_handler.retrieve_connection_pool("foo")
        assert_nil @ro_handler.retrieve_connection_pool("foo")
      end
    end
  end
end
