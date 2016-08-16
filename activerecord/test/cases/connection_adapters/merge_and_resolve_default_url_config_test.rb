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

      def resolve_config(config)
        ActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig.new(config).resolve
      end

      def resolve_spec(spec, config)
        ConnectionSpecification::Resolver.new(resolve_config(config)).resolve(spec)
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = resolve_spec(:default_env, config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost", "name"=>"default_env" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key_and_rails_env
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        ENV["RAILS_ENV"]    = "foo"

        config   = { "not_production" => { "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = resolve_spec(:foo, config)
        expected = { "adapter" => "postgresql", "database" => "foo", "host" => "localhost","name"=>"foo" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key_and_rack_env
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        ENV["RACK_ENV"]     = "foo"

        config   = { "not_production" => { "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = resolve_spec(:foo, config)
        expected = { "adapter" => "postgresql", "database" => "foo", "host" => "localhost","name"=>"foo" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_known_key
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config   = { "production" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
        actual   = resolve_spec(:production, config)
        expected = { "adapter"=>"not_postgres", "database"=>"not_foo", "host"=>"localhost", "name"=>"production" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_unknown_symbol_key
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        assert_raises AdapterNotSpecified do
          resolve_spec(:production, config)
        end
      end

      def test_resolver_with_database_uri_and_supplied_url
        ENV["DATABASE_URL"] = "not-postgres://not-localhost/not_foo"
        config   = { "production" => {  "adapter" => "also_not_postgres", "database" => "also_not_foo" } }
        actual   = resolve_spec("postgres://localhost/foo", config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_jdbc_url
        config   = { "production" => { "url" => "jdbc:postgres://localhost/foo" } }
        actual   = resolve_config(config)
        assert_equal config, actual
      end

      def test_environment_does_not_exist_in_config_url_does_exist
        ENV["DATABASE_URL"] = "postgres://localhost/foo"
        config      = { "not_default_env" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual      = resolve_config(config)
        expect_prod = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expect_prod, actual["default_env"]
      end

      def test_url_with_hyphenated_scheme
        ENV["DATABASE_URL"] = "ibm-db://localhost/foo"
        config   = { "default_env" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
        actual   = resolve_spec(:default_env, config)
        expected = { "adapter"=>"ibm_db", "database"=>"foo", "host"=>"localhost", "name"=>"default_env" }
        assert_equal expected, actual
      end

      def test_string_connection
        config   = { "default_env" => "postgres://localhost/foo" }
        actual   = resolve_config(config)
        expected = { "default_env" =>
                     { "adapter"  => "postgresql",
                       "database" => "foo",
                       "host"     => "localhost"
                      }
                    }
        assert_equal expected, actual
      end

      def test_url_sub_key
        config   = { "default_env" => { "url" => "postgres://localhost/foo" } }
        actual   = resolve_config(config)
        expected = { "default_env" =>
                     { "adapter"  => "postgresql",
                       "database" => "foo",
                       "host"     => "localhost"
                      }
                    }
        assert_equal expected, actual
      end

      def test_hash
        config = { "production" => { "adapter" => "postgres", "database" => "foo" } }
        actual = resolve_config(config)
        assert_equal config, actual
      end

      def test_blank
        config = {}
        actual = resolve_config(config)
        assert_equal config, actual
      end

      def test_blank_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = { "adapter"  => "postgresql",
                     "database" => "foo",
                     "host"     => "localhost" }
        assert_equal expected, actual["default_env"]
        assert_equal nil,      actual["production"]
        assert_equal nil,      actual["development"]
        assert_equal nil,      actual["test"]
        assert_equal nil,      actual[:default_env]
        assert_equal nil,      actual[:production]
        assert_equal nil,      actual[:development]
        assert_equal nil,      actual[:test]
      end

      def test_blank_with_database_url_with_rails_env
        ENV["RAILS_ENV"] = "not_production"
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = { "adapter"  => "postgresql",
                     "database" => "foo",
                     "host"     => "localhost" }

        assert_equal expected, actual["not_production"]
        assert_equal nil,      actual["production"]
        assert_equal nil,      actual["default_env"]
        assert_equal nil,      actual["development"]
        assert_equal nil,      actual["test"]
        assert_equal nil,      actual[:default_env]
        assert_equal nil,      actual[:not_production]
        assert_equal nil,      actual[:production]
        assert_equal nil,      actual[:development]
        assert_equal nil,      actual[:test]
      end

      def test_blank_with_database_url_with_rack_env
        ENV["RACK_ENV"] = "not_production"
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = { "adapter"  => "postgresql",
                     "database" => "foo",
                     "host"     => "localhost" }

        assert_equal expected, actual["not_production"]
        assert_equal nil,      actual["production"]
        assert_equal nil,      actual["default_env"]
        assert_equal nil,      actual["development"]
        assert_equal nil,      actual["test"]
        assert_equal nil,      actual[:default_env]
        assert_equal nil,      actual[:not_production]
        assert_equal nil,      actual[:production]
        assert_equal nil,      actual[:development]
        assert_equal nil,      actual[:test]
      end

      def test_database_url_with_ipv6_host_and_port
        ENV["DATABASE_URL"] = "postgres://[::1]:5454/foo"

        config   = {}
        actual   = resolve_config(config)
        expected = { "adapter"  => "postgresql",
                     "database" => "foo",
                     "host"     => "::1",
                     "port"     => 5454 }
        assert_equal expected, actual["default_env"]
      end

      def test_url_sub_key_with_database_url
        ENV["DATABASE_URL"] = "NOT-POSTGRES://localhost/NOT_FOO"

        config   = { "default_env" => { "url" => "postgres://localhost/foo" } }
        actual   = resolve_config(config)
        expected = { "default_env" =>
                    { "adapter"  => "postgresql",
                       "database" => "foo",
                       "host"     => "localhost"
                      }
                    }
        assert_equal expected, actual
      end

      def test_merge_no_conflicts_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = { "default_env" => { "pool" => "5" } }
        actual   = resolve_config(config)
        expected = { "default_env" =>
                     { "adapter"  => "postgresql",
                       "database" => "foo",
                       "host"     => "localhost",
                       "pool"     => "5"
                      }
                    }
        assert_equal expected, actual
      end

      def test_merge_conflicts_with_database_url
        ENV["DATABASE_URL"] = "postgres://localhost/foo"

        config   = { "default_env" => { "adapter" => "NOT-POSTGRES", "database" => "NOT-FOO", "pool" => "5" } }
        actual   = resolve_config(config)
        expected = { "default_env" =>
                     { "adapter"  => "postgresql",
                       "database" => "foo",
                       "host"     => "localhost",
                       "pool"     => "5"
                      }
                    }
        assert_equal expected, actual
      end
    end
  end
end
