require "cases/helper"

module ActiveRecord
  module ConnectionAdapters

    class MergeAndResolveDefaultUrlConfigTest < ActiveRecord::TestCase

      def klass
        ActiveRecord::ConnectionHandling::MergeAndResolveDefaultUrlConfig
      end

      def setup
        @previous_database_url = ENV.delete("DATABASE_URL")
        @previous_database_url_default_env = ENV.delete("DATABASE_URL_DEFAULT_ENV")
        @previous_database_url_production = ENV.delete("DATABASE_URL_PRODUCTION")
      end

      teardown do
        ENV["DATABASE_URL"] = @previous_database_url
        ENV["DATABASE_URL_DEFAULT_ENV"] = @previous_database_url_default_env
        ENV["DATABASE_URL_PRODUCTION"] = @previous_database_url_production
      end

      def resolve(spec, config)
        ConnectionSpecification::Resolver.new(klass.new(config).resolve).resolve(spec)
      end

      def spec(spec, config)
        ConnectionSpecification::Resolver.new(klass.new(config).resolve).spec(spec)
      end

      def test_resolver_with_database_uri_and_current_env_symbol_key
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = resolve(:default_env, config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_resolver_with_environment_database_uri_and_current_env_symbol_key
        ENV['DATABASE_URL_DEFAULT_ENV'] = "postgres://localhost/foo"
        config   = { "default_env" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = resolve(:default_env, config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_resolver_with_environment_database_uri_and_global_database_uri_and_current_env_symbol_key
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        ENV['DATABASE_URL_DEFAULT_ENV'] = "mysql://host/foo_bar"
        config   = { "default_env" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = resolve(:default_env, config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_and_current_env_string_key
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        config   = { "default_env" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual   = assert_deprecated { resolve("default_env", config) }
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_known_key
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        config   = { "production" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
        actual   = resolve(:production, config)
        expected = { "adapter"=>"not_postgres", "database"=>"not_foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_resolver_with_custom_database_uri_and_custom_key
        ENV['DATABASE_URL_PRODUCTION'] = "postgres://localhost/foo"
        config   = { "production" => { "adapter" => "not_postgres", "database" => "not_foo", "host" => "localhost" } }
        actual   = resolve(:production, config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_resolver_with_database_uri_and_unknown_symbol_key
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        assert_raises AdapterNotSpecified do
          resolve(:production, config)
        end
      end

      def test_resolver_with_database_uri_and_unknown_string_key
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        config   = { "not_production" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        assert_raises AdapterNotSpecified do
          spec("production", config)
        end
      end

      def test_resolver_with_database_uri_and_supplied_url
        ENV['DATABASE_URL'] = "not-postgres://not-localhost/not_foo"
        config   = { "production" => {  "adapter" => "also_not_postgres", "database" => "also_not_foo" } }
        actual   = resolve("postgres://localhost/foo", config)
        expected = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expected, actual
      end

      def test_jdbc_url
        config   = { "production" => { "url" => "jdbc:postgres://localhost/foo" } }
        actual   = klass.new(config).resolve
        assert_equal config, actual
      end

      def test_environment_does_not_exist_in_config_url_does_exist
        ENV['DATABASE_URL'] = "postgres://localhost/foo"
        config      = { "not_default_env" => {  "adapter" => "not_postgres", "database" => "not_foo" } }
        actual      = klass.new(config).resolve
        expect_prod = { "adapter"=>"postgresql", "database"=>"foo", "host"=>"localhost" }
        assert_equal expect_prod, actual["default_env"]
      end

      def test_string_connection
        config   = { "default_env" => "postgres://localhost/foo" }
        actual   = klass.new(config).resolve
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
        actual   = klass.new(config).resolve
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
        actual = klass.new(config).resolve
        assert_equal config, actual
      end

      def test_blank
        config = {}
        actual = klass.new(config).resolve
        assert_equal config, actual
      end

      def test_blank_with_database_url
        ENV['DATABASE_URL'] = "postgres://localhost/foo"

        config   = {}
        actual   = klass.new(config).resolve
        expected = { "adapter"  => "postgresql",
                     "database" => "foo",
                     "host"     => "localhost" }
        assert_equal expected, actual["default_env"]
        assert_equal nil,      actual["production"]
        assert_equal nil,      actual["development"]
        assert_equal nil,      actual["test"]
        assert_equal nil,      actual[:production]
        assert_equal nil,      actual[:development]
        assert_equal nil,      actual[:test]
      end

      def test_url_sub_key_with_database_url
        ENV['DATABASE_URL'] = "NOT-POSTGRES://localhost/NOT_FOO"

        config   = { "default_env" => { "url" => "postgres://localhost/foo" } }
        actual   = klass.new(config).resolve
        expected = { "default_env" =>
                    { "adapter"  => "postgresql",
                       "database" => "foo",
                       "host"     => "localhost"
                      }
                    }
        assert_equal expected, actual
      end

      def test_merge_no_conflicts_with_database_url
        ENV['DATABASE_URL'] = "postgres://localhost/foo"

        config   = {"default_env" => { "pool" => "5" } }
        actual   = klass.new(config).resolve
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
        ENV['DATABASE_URL'] = "postgres://localhost/foo"

        config   = {"default_env" => { "adapter" => "NOT-POSTGRES", "database" => "NOT-FOO", "pool" => "5" } }
        actual   = klass.new(config).resolve
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

    class ConnectionHandlerTest < ActiveRecord::TestCase
      def setup
        @klass    = Class.new(Base)   { def self.name; 'klass';    end }
        @subklass = Class.new(@klass) { def self.name; 'subklass'; end }

        @handler = ConnectionHandler.new
        @pool    = @handler.establish_connection(@klass, Base.connection_pool.spec)
      end

      def test_retrieve_connection
        assert @handler.retrieve_connection(@klass)
      end

      def test_active_connections?
        assert !@handler.active_connections?
        assert @handler.retrieve_connection(@klass)
        assert @handler.active_connections?
        @handler.clear_active_connections!
        assert !@handler.active_connections?
      end

      def test_retrieve_connection_pool_with_ar_base
        assert_nil @handler.retrieve_connection_pool(ActiveRecord::Base)
      end

      def test_retrieve_connection_pool
        assert_not_nil @handler.retrieve_connection_pool(@klass)
      end

      def test_retrieve_connection_pool_uses_superclass_when_no_subclass_connection
        assert_not_nil @handler.retrieve_connection_pool(@subklass)
      end

      def test_retrieve_connection_pool_uses_superclass_pool_after_subclass_establish_and_remove
        sub_pool = @handler.establish_connection(@subklass, Base.connection_pool.spec)
        assert_same sub_pool, @handler.retrieve_connection_pool(@subklass)

        @handler.remove_connection @subklass
        assert_same @pool, @handler.retrieve_connection_pool(@subklass)
      end

      def test_connection_pools
        assert_deprecated do
          assert_equal({ Base.connection_pool.spec => @pool }, @handler.connection_pools)
        end
      end
    end
  end
end
