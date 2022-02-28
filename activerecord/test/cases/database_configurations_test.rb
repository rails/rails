# frozen_string_literal: true

require "cases/helper"

class DatabaseConfigurationsTest < ActiveRecord::TestCase
  unless in_memory_db?
    def test_empty_returns_true_when_db_configs_are_empty
      old_config = ActiveRecord::Base.configurations
      config = {}

      ActiveRecord::Base.configurations = config

      assert_predicate ActiveRecord::Base.configurations, :empty?
      assert_predicate ActiveRecord::Base.configurations, :blank?
    ensure
      ActiveRecord::Base.configurations = old_config
      ActiveRecord::Base.establish_connection :arunit
    end
  end

  def test_configs_for_getter_with_env_name
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "arunit")

    assert_equal 1, configs.size
    assert_equal ["arunit"], configs.map(&:env_name)
  end

  def test_configs_for_getter_with_name
    previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit2"

    config = ActiveRecord::Base.configurations.configs_for(name: "primary")

    assert_equal "arunit2", config.env_name
    assert_equal "primary", config.name
  ensure
    ENV["RAILS_ENV"] = previous_env
  end

  def test_configs_for_getter_with_env_and_name
    config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary")

    assert_equal "arunit", config.env_name
    assert_equal "primary", config.name
  end

  def test_find_db_config_returns_first_config_for_env
    config = ActiveRecord::DatabaseConfigurations.new({
        "test" => {
          "config_1" => {
            "database" => "db"
          },
          "config_2" => {
            "database" => "db"
          },
          "config_3" => {
            "database" => "db"
          },
        }
      })

    assert_equal "config_1", config.find_db_config("test").name
  end

  def test_find_db_config_returns_a_db_config_object_for_the_given_env
    config = ActiveRecord::Base.configurations.find_db_config("arunit2")

    assert_equal "arunit2", config.env_name
    assert_equal "primary", config.name
  end

  def test_find_db_config_prioritize_db_config_object_for_the_current_env
    config = ActiveRecord::DatabaseConfigurations.new({
      "primary" => {
        "adapter" => "randomadapter"
      },
      ActiveRecord::ConnectionHandling::DEFAULT_ENV.call => {
        "primary" => {
          "adapter" => "sqlite3",
          "database" => ":memory:"
        }
      }
    }).find_db_config("primary")

    assert_equal "primary", config.name
    assert_equal ActiveRecord::ConnectionHandling::DEFAULT_ENV.call, config.env_name
    assert_equal ":memory:", config.database
  end
end

class LegacyDatabaseConfigurationsTest < ActiveRecord::TestCase
  def test_unsupported_method_raises
    assert_raises NoMethodError do
      ActiveRecord::Base.configurations.fetch(:foo)
    end
  end

  def test_hidden_returns_replicas
    config = {
      "default_env" => {
        "readonly" => { "adapter" => "sqlite3", "database" => "test/db/readonly.sqlite3", "replica" => true },
        "hidden" => { "adapter" => "sqlite3", "database" => "test/db/hidden.sqlite3", "database_tasks" => false },
        "default" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3" }
      }
    }
    prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

    assert_equal 1, ActiveRecord::Base.configurations.configs_for(env_name: "default_env").count
    assert_equal 3, ActiveRecord::Base.configurations.configs_for(env_name: "default_env", include_hidden: true).count
  ensure
    ActiveRecord::Base.configurations = prev_configs
  end

  def test_include_replicas_is_deprecated
    assert_deprecated do
      db_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit", name: "primary", include_replicas: true)

      assert_equal "primary", db_config.name
    end
  end
end
