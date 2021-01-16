# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class MergeAndResolveDefaultUrlConfigTest < ActiveRecord::TestCase
      def setup
        @previous_database_url = ENV.delete("DATABASE_URL")
        @previous_rack_env = ENV.delete("RACK_ENV")
        @previous_rails_env = ENV.delete("RAILS_ENV")
      end

      teardown do
        ENV["DATABASE_URL"] = @previous_database_url
        ENV["RACK_ENV"] = @previous_rack_env
        ENV["RAILS_ENV"] = @previous_rails_env
      end

      def resolve_config(config, env_name = ActiveRecord::ConnectionHandling::DEFAULT_ENV.call)
        configs = ActiveRecord::DatabaseConfigurations.new(config)
        configs.configs_for(env_name: env_name, name: "primary")&.configuration_hash
      end

      def resolve_db_config(spec, config)
        configs = ActiveRecord::DatabaseConfigurations.new(config)
        configs.resolve(spec)
      end

      def test_invalid_string_config
        config = { "foo" => "bar" }

        assert_raises ActiveRecord::DatabaseConfigurations::InvalidConfigurationError do
          resolve_config(config)
        end
      end

      def test_invalid_symbol_config
        config = { "foo" => :bar }

        assert_raises ActiveRecord::DatabaseConfigurations::InvalidConfigurationError do
          resolve_config(config)
        end
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual = resolve_db_config(:default_env, config)
        expected = { adapter: "postgresql", database: "foo", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key_and_rails_env
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        ENV["RAILS_ENV"]    = "foo"

        config = { "not_production" => { "adapter" => "not_postgres", "database" => "not_foo" } }
        actual = resolve_db_config(:foo, config)
        expected = { adapter: "postgresql", database: "foo", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_resolver_with_nil_database_url_and_current_env
        ENV["RAILS_ENV"] = "foo"
        config = { "foo" => { "adapter" => "postgres", "url" => ENV["DATABASE_URL"] } }
        actual = resolve_db_config(:foo, config)
        expected_config = { adapter: "postgres", url: nil }

        assert_equal expected_config, actual.configuration_hash
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key_and_rack_env
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        ENV["RACK_ENV"]     = "foo"

        config = { "not_production" => { "adapter" => "not_postgres", "database" => "not_foo" } }
        actual = resolve_db_config(:foo, config)
        expected = { adapter: "postgresql", database: "foo", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_resolver_with_database_uri_and_known_key
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config = { "production" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
        actual = resolve_db_config(:production, config)
        expected = { adapter: "not_postgres", database: "not_foo", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_resolver_with_database_uri_and_multiple_envs
        ENV["DATABASE_URL"] = "postgres://localhost"
        ENV["RAILS_ENV"] = "test"

        config = { "production" => { "adapter" => "postgresql", "database" => "foo_prod" }, "test" => { "adapter" => "postgresql", "database" => "foo_test" } }
        actual = resolve_db_config(:test, config)
        expected = { adapter: "postgresql", database: "foo_test", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_resolver_with_database_uri_and_unknown_symbol_key
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        assert_raises AdapterNotSpecified do
          resolve_db_config(:production, config)
        end
      end

      def test_resolver_with_database_uri_and_supplied_url
        ENV["DATABASE_URL"] = "not-postgres://not-localhost/not_foo"
        config = { "production" => {  "adapter" => "also_not_postgres", "database" => "also_not_foo" } }
        actual = resolve_db_config("postgres://localhost/foo", config)
        expected = { adapter: "postgresql", database: "foo", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_jdbc_url
        config   = { "production" => { "url" => "jdbc:postgres://localhost/foo" } }
        actual   = resolve_config(config, "production")
        assert_equal config["production"].symbolize_keys, actual
      end

      def test_adapter_with_url_config
        config   = { "production" => { "adapter" => "sunstone", "url" => "https://example.com/path" } }
        actual   = resolve_config(config, "production")
        assert_equal config["production"].symbolize_keys, actual

        config = { "default_env" => { "adapter" => "not_postgres", "url" => "foo" } }
        actual = resolve_db_config(:default_env, config)
        expected = { adapter: "not_postgres", url: "foo" }

        assert_equal expected, actual.configuration_hash
      end

      def test_environment_does_not_exist_in_config_url_does_exist
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config      = { "not_default_env" => { "adapter" => "not_postgres", "database" => "not_foo" } }
        actual      = resolve_config(config, "default_env")
        expect_prod = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expect_prod, actual
      end

      def test_url_with_hyphenated_scheme
        ENV["DATABASE_URL"] = "ibm-db://localhost/foo"
        config = { "default_env" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
        actual = resolve_db_config(:default_env, config)
        expected = { adapter: "ibm_db", database: "foo", host: "localhost" }

        assert_equal expected, actual.configuration_hash
      end

      def test_string_connection
        config   = { "default_env" => "postgres://localhost/foo" }
        actual   = resolve_config(config, "default_env")
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expected, actual
      end

      def test_url_sub_key
        config   = { "default_env" => { "url" => "postgres://localhost/foo" } }
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expected, actual
      end

      def test_url_removed_from_hash
        config = { "default_env" => { "url" => "postgres://localhost/foo" } }
        actual = resolve_db_config(:default_env, config)

        assert_not_includes actual.configuration_hash, :url
      end

      def test_url_with_equals_in_query_value
        config   = { "default_env" => { "url" => "postgresql://localhost/foo?options=-cmyoption=on" } }
        actual   = resolve_config(config)
        expected = { options: "-cmyoption=on", adapter: "postgresql", database: "foo", host: "localhost" }
        assert_equal expected, actual
      end

      def test_hash
        config = { "production" => { "adapter" => "postgres", "database" => "foo" } }
        actual = resolve_config(config, "production")
        assert_equal config["production"].symbolize_keys, actual
      end

      def test_blank
        config = {}
        actual = resolve_config(config, "default_env")
        assert_nil actual
      end

      def test_blank_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expected, actual
      end

      def test_blank_with_database_url_with_rails_env
        ENV["RAILS_ENV"] = "not_production"
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expected, actual
      end

      def test_blank_with_database_url_with_rack_env
        ENV["RACK_ENV"] = "not_production"
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expected, actual
      end

      def test_database_url_with_ipv6_host_and_port
        ENV["DATABASE_URL"] = "postgres://[::1]:5454/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "::1",
          port: 5454
        }

        assert_equal expected, actual
      end

      def test_url_sub_key_with_database_url
        ENV["DATABASE_URL"] = "NOT-POSTGRES://localhost/NOT_FOO"

        config   = { "default_env" => { "url" => "postgres://localhost/foo" } }
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost"
        }

        assert_equal expected, actual
      end

      def test_no_url_sub_key_with_database_url_doesnt_trample_other_envs
        ENV["DATABASE_URL"] = "postgres://localhost/baz"

        config   = { "default_env" => { "database" => "foo" }, "other_env" => { "url" => "postgres://foohost/bardb" } }
        expected = {
          default_env: {
            database: "baz",
            adapter: "postgresql",
            host: "localhost"
          },
          other_env: {
            adapter: "postgresql",
            database: "bardb",
            host: "foohost"
          }
        }

        assert_equal expected[:default_env], resolve_config(config, "default_env")
        assert_equal expected[:other_env], resolve_config(config, "other_env")
      end

      def test_merge_no_conflicts_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = { "default_env" => { "pool" => "5" } }
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost",
          pool: "5"
        }

        assert_equal expected, actual
      end

      def test_merge_conflicts_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = { "default_env" => { "adapter" => "NOT-POSTGRES", "database" => "NOT-FOO", "pool" => "5" } }
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost",
          pool: "5"
        }

        assert_equal expected, actual
      end

      def test_merge_no_conflicts_with_database_url_and_adapter
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = { "default_env" => { "adapter" => "postgresql", "pool" => "5" } }
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost",
          pool: "5"
        }

        assert_equal expected, actual
      end

      def test_merge_no_conflicts_with_database_url_and_numeric_pool
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = { "default_env" => { "pool" => 5 } }
        actual   = resolve_config(config)
        expected = {
          adapter: "postgresql",
          database: "foo",
          host: "localhost",
          pool: 5
        }

        assert_equal expected, actual
      end

      def test_tiered_configs_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config = {
          "default_env" => {
            "primary" => { "pool" => 5 },
            "animals" => { "pool" => 5 }
          }
        }

        configs = ActiveRecord::DatabaseConfigurations.new(config)
        actual = configs.configs_for(env_name: "default_env", name: "primary").configuration_hash
        expected = {
          adapter:  "postgresql",
          database: "foo",
          host:     "localhost",
          pool:     5
        }

        assert_equal expected, actual

        configs = ActiveRecord::DatabaseConfigurations.new(config)
        actual = configs.configs_for(env_name: "default_env", name: "animals").configuration_hash
        expected = { pool: 5 }

        assert_equal expected, actual
      end

      def test_separate_database_env_vars
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        ENV["PRIMARY_DATABASE_URL"] = "postgres://localhost/primary"
        ENV["ANIMALS_DATABASE_URL"] = "postgres://localhost/animals"

        config = {
          "default_env" => {
            "primary" => { "pool" => 5 },
            "animals" => { "pool" => 5 }
          }
        }

        configs = ActiveRecord::DatabaseConfigurations.new(config)
        actual = configs.configs_for(env_name: "default_env", name: "primary").configuration_hash
        assert_equal "primary", actual[:database]

        configs = ActiveRecord::DatabaseConfigurations.new(config)
        actual = configs.configs_for(env_name: "default_env", name: "animals").configuration_hash
        assert_equal "animals", actual[:database]
      ensure
        ENV.delete("PRIMARY_DATABASE_URL")
        ENV.delete("ANIMALS_DATABASE_URL")
      end

      def test_does_not_change_other_environments
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config = { "production" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" }, "default_env" => {} }

        actual = resolve_db_config(:production, config)
        assert_equal config["production"].symbolize_keys, actual.configuration_hash

        actual = resolve_db_config(:default_env, config)

        assert_equal({
          host: "localhost",
          database: "foo",
          adapter: "postgresql",
        }, actual.configuration_hash)
      end
    end
  end
end
