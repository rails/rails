# frozen_string_literal: true

require "cases/helper"
require "models/person"

module ActiveRecord
  module ConnectionAdapters
    class ConnectionHandlerTest < ActiveRecord::TestCase
      fixtures :people

      def setup
        @handler = ConnectionHandler.new
        @connection_name = "ActiveRecord::Base"
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
        @pool = @handler.establish_connection(db_config)
      end

      def teardown
        clean_up_connection_handler
      end

      def test_default_env_fall_back_to_default_env_when_rails_env_or_rack_env_is_empty_string
        original_rails_env = ENV["RAILS_ENV"]
        original_rack_env  = ENV["RACK_ENV"]
        ENV["RAILS_ENV"]   = ENV["RACK_ENV"] = ""

        assert_equal "default_env", ActiveRecord::ConnectionHandling::DEFAULT_ENV.call
      ensure
        ENV["RAILS_ENV"] = original_rails_env
        ENV["RACK_ENV"]  = original_rack_env
      end

      def test_establish_connection_using_3_levels_config
        previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

        config = {
          "default_env" => {
            "readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" },
            "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
          },
          "another_env" => {
            "readonly" => { "adapter" => "sqlite3", "database" => "test/db/bad-readonly.sqlite3" },
            "primary"  => { "adapter" => "sqlite3", "database" => "test/db/bad-primary.sqlite3" }
          },
          "common" => { "adapter" => "sqlite3", "database" => "test/db/common.sqlite3" }
        }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:common)
        @handler.establish_connection(:primary)
        @handler.establish_connection(:readonly)

        assert_not_nil pool = @handler.retrieve_connection_pool("readonly")
        assert_equal "test/db/readonly.sqlite3", pool.db_config.database

        assert_not_nil pool = @handler.retrieve_connection_pool("primary")
        assert_equal "test/db/primary.sqlite3", pool.db_config.database

        assert_not_nil pool = @handler.retrieve_connection_pool("common")
        assert_equal "test/db/common.sqlite3", pool.db_config.database
      ensure
        ActiveRecord::Base.configurations = @prev_configs
        ENV["RAILS_ENV"] = previous_env
      end

      def test_validates_db_configuration_and_raises_on_invalid_adapter
        config = {
          "development" => { "adapter" => "ridiculous" },
        }

        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        assert_raises(ActiveRecord::AdapterNotFound) do
          ActiveRecord::Base.establish_connection(:development)
        end
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      unless in_memory_db?
        def test_not_setting_writing_role_while_using_another_named_role_raises
          connection_handler = ActiveRecord::Base.connection_handler
          ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new

          ActiveRecord::Base.connects_to(shards: { default: { also_writing: :arunit }, one: { also_writing: :arunit } })

          assert_raises(ArgumentError) { setup_shared_connection_pool }
        ensure
          ActiveRecord::Base.connection_handler = connection_handler
        end

        def test_fixtures_dont_raise_if_theres_no_writing_pool_config
          connection_handler = ActiveRecord::Base.connection_handler
          ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new

          assert_nothing_raised do
            ActiveRecord::Base.connects_to(database: { reading: :arunit, writing: :arunit })
          end

          rw_conn = ActiveRecord::Base.connection_handler.retrieve_connection("ActiveRecord::Base", role: :writing)
          ro_conn = ActiveRecord::Base.connection_handler.retrieve_connection("ActiveRecord::Base", role: :reading)

          assert_equal rw_conn, ro_conn
        ensure
          ActiveRecord::Base.connection_handler = connection_handler
        end

        def test_setting_writing_role_while_using_another_named_role_does_not_raise
          connection_handler = ActiveRecord::Base.connection_handler
          ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
          old_role, ActiveRecord.writing_role = ActiveRecord.writing_role, :also_writing

          ActiveRecord::Base.connects_to(shards: { default: { also_writing: :arunit }, one: { also_writing: :arunit } })

          assert_nothing_raised { setup_shared_connection_pool }
        ensure
          ActiveRecord.writing_role = old_role
          ActiveRecord::Base.connection_handler = connection_handler
        end

        def test_establish_connection_with_primary_works_without_deprecation
          old_config = ActiveRecord::Base.configurations
          config = { "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" } }
          ActiveRecord::Base.configurations = config

          @handler.establish_connection(:primary)

          assert_not_deprecated(ActiveRecord.deprecator) do
            @handler.retrieve_connection("primary")
            @handler.remove_connection_pool("primary")
          end
        ensure
          ActiveRecord::Base.configurations = old_config
        end

        def test_establish_connection_using_3_level_config_defaults_to_default_env_primary_db
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
              "readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" }
            },
            "another_env" => {
              "primary"  => { "adapter" => "sqlite3", "database" => "test/db/another-primary.sqlite3" },
              "readonly" => { "adapter" => "sqlite3", "database" => "test/db/another-readonly.sqlite3" }
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.establish_connection

          assert_match "test/db/primary.sqlite3", ActiveRecord::Base.lease_connection.pool.db_config.database
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ENV["RAILS_ENV"] = previous_env
          ActiveRecord::Base.establish_connection(:arunit)
        end

        def test_establish_connection_using_2_level_config_defaults_to_default_env_primary_db
          previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"

          config = {
            "default_env" => {
              "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3"
            },
            "another_env" => {
              "adapter" => "sqlite3", "database" => "test/db/bad-primary.sqlite3"
            }
          }
          @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

          ActiveRecord::Base.establish_connection

          assert_match "test/db/primary.sqlite3", ActiveRecord::Base.lease_connection.pool.db_config.database
        ensure
          ActiveRecord::Base.configurations = @prev_configs
          ENV["RAILS_ENV"] = previous_env
          ActiveRecord::Base.establish_connection(:arunit)
        end
      end

      def test_establish_connection_using_two_level_configurations
        config = { "development" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" } }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:development)

        assert_not_nil pool = @handler.retrieve_connection_pool("development")
        assert_not_predicate pool.lease_connection, :preventing_writes?
        assert_equal "test/db/primary.sqlite3", pool.db_config.database
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      def test_establish_connection_using_top_level_key_in_two_level_config
        config = {
          "development" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
          "development_readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" }
        }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:development_readonly)

        assert_not_nil pool = @handler.retrieve_connection_pool("development_readonly")
        assert_not_predicate pool.lease_connection, :preventing_writes?
        assert_equal "test/db/readonly.sqlite3", pool.db_config.database
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      def test_establish_connection_with_string_owner_name
        config = {
          "development" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
          "development_readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3" }
        }
        @prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

        @handler.establish_connection(:development_readonly, owner_name: "custom_connection")

        assert_not_nil pool = @handler.retrieve_connection_pool("custom_connection")
        assert_not_predicate pool.lease_connection, :preventing_writes?
        assert_equal "test/db/readonly.sqlite3", pool.db_config.database
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      def test_symbolized_configurations_assignment
        @prev_configs = ActiveRecord::Base.configurations
        config = {
          development: {
            primary: {
              adapter: "sqlite3",
              database: "test/storage/development.sqlite3",
            },
          },
          test: {
            primary: {
              adapter: "sqlite3",
              database: "test/storage/test.sqlite3",
            },
          },
        }
        ActiveRecord::Base.configurations = config
        ActiveRecord::Base.configurations.configs_for.each do |db_config|
          assert_instance_of ActiveRecord::DatabaseConfigurations::HashConfig, db_config
          assert_instance_of String, db_config.env_name
          assert_instance_of String, db_config.name

          db_config.configuration_hash.keys.each do |key|
            assert_instance_of Symbol, key
          end
        end
      ensure
        ActiveRecord::Base.configurations = @prev_configs
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@connection_name)
      end

      def test_active_connections?
        assert_not @handler.active_connections?(:all)
        assert @handler.retrieve_connection(@connection_name)
        assert @handler.active_connections?(:all)
        @handler.clear_active_connections!(:all)
        assert_not @handler.active_connections?(:all)
      end

      def test_retrieve_connection_pool
        assert_not_nil @handler.retrieve_connection_pool(@connection_name)
      end

      def test_retrieve_connection_pool_with_invalid_id
        assert_nil @handler.retrieve_connection_pool("foo")
      end

      def test_connection_pools
        assert_equal([@pool], @handler.connection_pools)
      end

      def test_a_class_using_custom_pool_and_switching_back_to_primary
        klass2 = Class.new(Base) { def self.name; "klass2"; end }

        assert_same klass2.lease_connection, ActiveRecord::Base.lease_connection

        pool = klass2.establish_connection(ActiveRecord::Base.connection_pool.db_config.configuration_hash)
        assert_same klass2.lease_connection, pool.lease_connection
        assert_not_same klass2.lease_connection, ActiveRecord::Base.lease_connection

        klass2.remove_connection

        assert_same klass2.lease_connection, ActiveRecord::Base.lease_connection
      end

      class ApplicationRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      class MyClass < ApplicationRecord
      end

      def test_connection_specification_name_should_fallback_to_parent
        Object.const_set :ApplicationRecord, ApplicationRecord

        klassA = Class.new(Base)
        klassB = Class.new(klassA)
        klassC = Class.new(MyClass)

        assert_equal klassB.connection_specification_name, klassA.connection_specification_name
        assert_equal klassC.connection_specification_name, klassA.connection_specification_name

        assert_equal "ActiveRecord::Base", klassA.connection_specification_name
        assert_equal "ActiveRecord::Base", klassC.connection_specification_name

        klassA.connection_specification_name = "readonly"
        assert_equal "readonly", klassB.connection_specification_name

        ActiveRecord::Base.connection_specification_name = "readonly"
        assert_equal "readonly", klassC.connection_specification_name
      ensure
        ApplicationRecord.remove_connection
        Object.send :remove_const, :ApplicationRecord
        ActiveRecord::Base.connection_specification_name = "ActiveRecord::Base"
      end

      def test_remove_connection_should_not_remove_parent
        klass2 = Class.new(Base) { def self.name; "klass2"; end }
        klass2.remove_connection
        assert_not_nil ActiveRecord::Base.lease_connection
        assert_same klass2.lease_connection, ActiveRecord::Base.lease_connection
      end

      def test_default_handlers_are_writing_and_reading
        assert_equal :writing, ActiveRecord.writing_role
        assert_equal :reading, ActiveRecord.reading_role
      end

      if Process.respond_to?(:fork)
        def test_connection_pool_per_pid
          object_id = ActiveRecord::Base.lease_connection.object_id

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            wr.write Marshal.dump ActiveRecord::Base.lease_connection.object_id
            wr.close
            exit!
          }

          wr.close

          Process.waitpid pid
          assert_not_equal object_id, Marshal.load(rd.read)
          rd.close
        end

        def test_forked_child_doesnt_mangle_parent_connection
          object_id = ActiveRecord::Base.lease_connection.object_id
          assert_predicate ActiveRecord::Base.lease_connection, :active?

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            wr.write Marshal.dump [
              ActiveRecord::Base.lease_connection.object_id,
            ]
            wr.close

            exit # allow finalizers to run
          }

          wr.close

          Process.waitpid pid
          child_id = Marshal.load(rd.read)
          assert_not_equal object_id, child_id
          rd.close

          assert_equal 3, ActiveRecord::Base.lease_connection.select_value("SELECT COUNT(*) FROM people")
        end

        unless in_memory_db?
          def test_forked_child_recovers_from_disconnected_parent
            object_id = ActiveRecord::Base.lease_connection.object_id
            assert_predicate ActiveRecord::Base.lease_connection, :active?

            rd, wr = IO.pipe
            rd.binmode
            wr.binmode

            outer_pid = fork {
              ActiveRecord::Base.lease_connection.disconnect!

              pid = fork {
                rd.close
                wr.write Marshal.dump [
                  !!ActiveRecord::Base.lease_connection.active?,
                  ActiveRecord::Base.lease_connection.object_id,
                  ActiveRecord::Base.lease_connection.select_value("SELECT COUNT(*) FROM people"),
                ]
                wr.close

                exit # allow finalizers to run
              }

              Process.waitpid pid
            }

            wr.close

            Process.waitpid outer_pid
            active, child_id, child_count = Marshal.load(rd.read)

            assert_equal false, active
            assert_not_equal object_id, child_id
            rd.close

            assert_equal 3, child_count

            # Outer connection is unaffected
            assert_equal 6, ActiveRecord::Base.lease_connection.select_value("SELECT 2 * COUNT(*) FROM people")
          end
        end

        def test_retrieve_connection_pool_copies_schema_cache_from_ancestor_pool
          @pool.schema_cache.add("posts")

          rd, wr = IO.pipe
          rd.binmode
          wr.binmode

          pid = fork {
            rd.close
            pool = @handler.retrieve_connection_pool(@connection_name)
            wr.write Marshal.dump pool.schema_cache.size
            wr.close
            exit!
          }

          wr.close

          Process.waitpid pid
          assert_equal @pool.schema_cache.size, Marshal.load(rd.read)
          rd.close
        end

        if current_adapter?(:SQLite3Adapter)
          def test_pool_from_any_process_for_uses_most_recent_spec
            file = Tempfile.new "lol.sqlite3"

            rd, wr = IO.pipe
            rd.binmode
            wr.binmode

            pid = fork do
              config_hash = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").configuration_hash.merge(database: file.path)
              ActiveRecord::Base.establish_connection(config_hash)

              pid2 = fork do
                wr.write ActiveRecord::Base.connection_db_config.database
                wr.close
              end

              Process.waitpid pid2
            end

            Process.waitpid pid

            wr.close

            assert_equal file.path, rd.read

            rd.close
          ensure
            if file
              file.close
              file.unlink
            end
          end
        end
      end
    end
  end
end
