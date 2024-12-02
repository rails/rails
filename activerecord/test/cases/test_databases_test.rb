# frozen_string_literal: true

require "cases/helper"
require "active_record/test_databases"

class TestDatabasesTest < ActiveRecord::TestCase
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

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _, _) {
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

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _, _) {
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

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _, _) {
        assert_equal base_configs_order, ActiveRecord::Base.configurations.configs_for(env_name: "arunit").map(&:name)
      }) do
        ActiveSupport::Testing::Parallelization.after_fork_hooks.each { |cb| cb.call(idx) }
      end
    ensure
      ActiveRecord::Base.configurations = prev_configs
      ActiveRecord::Base.establish_connection(:arunit)
      ENV["RAILS_ENV"] = previous_env
    end
  end
end
