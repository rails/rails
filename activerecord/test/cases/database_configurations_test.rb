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
    end
  end

  def test_configs_for_getter_with_env_name
    configs = ActiveRecord::Base.configurations.configs_for(env_name: "arunit")

    assert_equal 1, configs.size
    assert_equal ["arunit"], configs.map(&:env_name)
  end

  def test_warns_when_url_and_conflicting_key_are_given_in_the_same_config
    warning = capture(:stderr) do
      ActiveRecord::DatabaseConfigurations.new(
        "default_env" => { "primary" => { "url" => "postgres://localhost/from_url", "database" => "from_yaml" } }
      ).configs_for(env_name: "default_env")
    end

    assert_match(/\bdatabase\b/, warning)
    assert_match(/url/, warning)
  end

  def test_does_not_warn_when_only_a_url_is_given
    warning = capture(:stderr) do
      ActiveRecord::DatabaseConfigurations.new(
        "default_env" => { "primary" => { "url" => "postgres://localhost/from_url" } }
      ).configs_for(env_name: "default_env")
    end

    assert_predicate warning, :blank?, "expected no warning, got:\n#{warning}"
  end

  def test_does_not_warn_when_the_explicit_key_matches_the_url
    warning = capture(:stderr) do
      ActiveRecord::DatabaseConfigurations.new(
        "default_env" => { "primary" => { "url" => "postgres://localhost/same_db", "database" => "same_db" } }
      ).configs_for(env_name: "default_env")
    end

    assert_predicate warning, :blank?, "expected no warning, got:\n#{warning}"
  end

  def test_does_not_warn_when_the_url_comes_from_the_environment
    previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "default_env"
    previous_url, ENV["DATABASE_URL"] = ENV["DATABASE_URL"], "postgres://localhost/from_env"

    warning = capture(:stderr) do
      ActiveRecord::DatabaseConfigurations.new(
        "default_env" => { "primary" => { "adapter" => "sqlite3", "database" => "from_yaml" } }
      ).configs_for(env_name: "default_env")
    end

    assert_predicate warning, :blank?, "expected no warning for a DATABASE_URL override, got:\n#{warning}"
  ensure
    ENV["RAILS_ENV"] = previous_env
    ENV["DATABASE_URL"] = previous_url
  end

  def test_configs_for_getter_with_name
    previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit2"

    config = ActiveRecord::Base.configurations.configs_for(name: "primary")

    assert_equal "arunit2", config.env_name
    assert_equal "primary", config.name
  ensure
    ENV["RAILS_ENV"] = previous_env
  end

  def test_configs_for_with_name_symbol
    previous_env, ENV["RAILS_ENV"] = ENV["RAILS_ENV"], "arunit2"

    config = ActiveRecord::Base.configurations.configs_for(name: :primary)

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
            "adapter" => "abstract",
            "database" => "db"
          },
          "config_2" => {
            "adapter" => "abstract",
            "database" => "db"
          },
          "config_3" => {
            "adapter" => "abstract",
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
        "adapter" => "abstract",
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

  class CustomHashConfig < ActiveRecord::DatabaseConfigurations::HashConfig
    def sharded?
      custom_config.fetch("sharded", false)
    end

    private
      def custom_config
        configuration_hash.fetch(:custom_config)
      end
  end

  def test_registering_a_custom_config_object
    previous_handlers = ActiveRecord::DatabaseConfigurations.db_config_handlers

    ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, _, config|
      next unless config.key?(:custom_config)
      CustomHashConfig.new(env_name, name, config)
    end

    configs = ActiveRecord::DatabaseConfigurations.new({
      "test" => {
        "config_1" => {
          "adapter" => "abstract",
          "database" => "db",
          "custom_config" => {
            "sharded" => 1
          }
        },
        "config_2" => {
          "adapter" => "abstract",
          "database" => "db"
        }
      }
    }).configurations

    custom_config = configs.first
    hash_config = configs.last

    assert custom_config.is_a?(CustomHashConfig)
    assert hash_config.is_a?(ActiveRecord::DatabaseConfigurations::HashConfig)

    assert_predicate custom_config, :sharded?
  ensure
    ActiveRecord::DatabaseConfigurations.db_config_handlers = previous_handlers
  end

  def test_configs_for_with_custom_key
    previous_handlers = ActiveRecord::DatabaseConfigurations.db_config_handlers

    ActiveRecord::DatabaseConfigurations.register_db_config_handler do |env_name, name, _, config|
      next unless config.key?(:custom_config)
      CustomHashConfig.new(env_name, name, config)
    end

    config = {
      "default_env" => {
        "primary" => { "adapter" => "sqlite3", "database" => "test/db/primary.sqlite3", "custom_config" => { "sharded" => 1 } },
        "replica" => { "adapter" => "sqlite3", "database" => "test/db/hidden.sqlite3", "replica" => true, "custom_config" => { "sharded" => 1 } },
        "secondary" => { "adapter" => "sqlite3", "database" => "test/db/secondary.sqlite3" }
      }
    }
    prev_configs, ActiveRecord::Base.configurations = ActiveRecord::Base.configurations, config

    assert_equal 1, ActiveRecord::Base.configurations.configs_for(env_name: "default_env", config_key: :custom_config).count
    assert_equal 2, ActiveRecord::Base.configurations.configs_for(env_name: "default_env", config_key: :custom_config, include_hidden: true).count
    assert_equal 2, ActiveRecord::Base.configurations.configs_for(env_name: "default_env").count
  ensure
    ActiveRecord::DatabaseConfigurations.db_config_handlers = previous_handlers
    ActiveRecord::Base.configurations = prev_configs
  end

  def test_configs_for_with_include_hidden
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
end
