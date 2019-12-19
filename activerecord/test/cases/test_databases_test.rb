# frozen_string_literal: true

require "cases/helper"

class TestDatabasesTest < ActiveRecord::TestCase
  unless in_memory_db?
    def test_databases_are_created
      previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit"

      base_db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", spec_name: "primary")
      expected_database = "#{base_db_config.database}-2"

      ActiveRecord::Tasks::DatabaseTasks.stub(:reconstruct_from_schema, ->(db_config, _, _) {
        assert_equal expected_database, db_config.database
      }) do
        ActiveRecord::TestDatabases.create_and_load_schema(2, env_name: "arunit")
      end
    ensure
      ENV["RAILS_ENV"] = previous_env
    end
  end
end
