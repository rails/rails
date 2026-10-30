# frozen_string_literal: true

require "cases/helper"
require "active_record/test_databases"

class TestDatabasesTest < ActiveRecord::TestCase
  def test_connection_pools_are_usable_in_run_cleanup_hooks
    ActiveSupport::Testing::Parallelization.run_cleanup_hooks.each { |cb| cb.call(0) }

    assert_not_predicate ActiveRecord::Base.connection_pool, :discarded?
    assert_equal 1, ActiveRecord::Base.lease_connection.select_value("SELECT 1")
  end

  unless in_memory_db?
    def test_databases_are_created
      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit"
      prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, {
        "arunit" => {
          "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
        }
      }

      base_db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      expected_database = "#{base_db_config.database}_2"

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _) {
        assert_equal expected_database, db_config.database
      }) do
        ActiveRecord::TestDatabases.create_and_load_schema(2, env_name: "arunit")
      end
    ensure
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end

    def test_create_databases_after_fork
      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit"
      prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, {
        "arunit" => {
          "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
        }
      }

      idx = 42
      base_db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      expected_database = "#{base_db_config.database}_#{idx}"

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _) {
        assert_equal expected_database, db_config.database
      }) do
        ActiveSupport::Testing::Parallelization.after_fork_hooks.each { |cb| cb.call(idx) }
      end

      # Updates the database configuration
      assert_equal expected_database, ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").database
    ensure
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end

    def test_create_databases_skipped_if_parallelize_test_databases_is_false
      parallelize_databases = ActiveSupport.parallelize_test_databases
      ActiveSupport.parallelize_test_databases = false

      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit"
      prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, {
        "arunit" => {
          "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
        }
      }

      idx = 42
      base_db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      expected_database = "#{base_db_config.database}"

      ActiveSupport::Testing::Parallelization.after_fork_hooks.each { |cb| cb.call(idx) }

      # In this case, there should be no updates
      assert_equal expected_database, ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").database
    ensure
      ActiveSupport.parallelize_test_databases = parallelize_databases
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end

    def test_order_of_configurations_isnt_changed_by_test_databases
      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit"
      prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, {
        "arunit" => {
          "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
          "replica" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
        }
      }

      idx = 42
      base_configs_order = ActiveRecord::Base.configurations.configs_for(env_name: "arunit").map(&:name)

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _) {
        assert_equal base_configs_order, ActiveRecord::Base.configurations.configs_for(env_name: "arunit").map(&:name)
      }) do
        ActiveSupport::Testing::Parallelization.after_fork_hooks.each { |cb| cb.call(idx) }
      end
    ensure
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end

    def test_create_databases_after_fork_with_replica
      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit"
      prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, {
        "arunit" => {
          "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" },
          "replica" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "replica" => true }
        }
      }

      idx = 42
      primary_db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")
      expected_primary_database = "#{primary_db_config.database}_#{idx}"
      replica_db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "replica", include_hidden: true)
      expected_replica_database = "#{replica_db_config.database}_#{idx}"

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _) {
        assert_equal expected_primary_database, db_config.database
      }) do
        ActiveSupport::Testing::Parallelization.after_fork_hooks.each { |cb| cb.call(idx) }
      end

      # Updates the database configuration
      assert_equal expected_primary_database, ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary").database
      assert_equal expected_replica_database, ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "replica", include_hidden: true).database
    ensure
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end
  end
end

class TestDatabasesShutdownHookTest < ActiveRecord::TestCase
  self.use_transactional_tests = false

  def test_connection_pools_are_discarded_in_shutdown_hooks
    db_config = ActiveRecord::Base.connection_db_config
    old_handler = ActiveRecord::Base.connection_handler
    ActiveRecord::Base.connection_handler = ActiveRecord::ConnectionAdapters::ConnectionHandler.new
    pool = ActiveRecord::Base.establish_connection(db_config)

    ActiveSupport::Testing::Parallelization.shutdown_hooks.each(&:call)

    assert_predicate pool, :discarded?
  ensure
    ActiveRecord::Base.connection_handler = old_handler
  end
end
