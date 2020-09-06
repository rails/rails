# frozen_string_literal: true

require 'cases/helper'

module ActiveRecord
  module ConnectionAdapters
    class PoolConfig
      class ResolverTest < ActiveRecord::TestCase
        def resolve_db_config(pool_config, config = {})
          configs = ActiveRecord::DatabaseConfigurations.new(config)
          configs.resolve(pool_config)
        end

        def test_url_invalid_adapter
          error = assert_raises(LoadError) do
            Base.connection_handler.establish_connection 'ridiculous://foo?encoding=utf8'
          end

          assert_match "Could not load the 'ridiculous' Active Record adapter. Ensure that the adapter is spelled correctly in config/database.yml and that you've added the necessary adapter gem to your Gemfile.", error.message
        end

        def test_error_if_no_adapter_method
          error = assert_raises(AdapterNotFound) do
            Base.connection_handler.establish_connection 'abstract://foo?encoding=utf8'
          end

          assert_match 'database configuration specifies nonexistent abstract adapter', error.message
        end

        # The abstract adapter is used simply to bypass the bit of code that
        # checks that the adapter file can be required in.

        def test_url_from_environment
          pool_config = resolve_db_config :production, 'production' => 'abstract://foo?encoding=utf8'

          assert_equal({
            adapter:  'abstract',
            host:     'foo',
            encoding: 'utf8'
          }, pool_config.configuration_hash)
        end

        def test_url_sub_key
          pool_config = resolve_db_config :production, 'production' => { 'url' => 'abstract://foo?encoding=utf8' }

          assert_equal({
            adapter:  'abstract',
            host:     'foo',
            encoding: 'utf8'
          }, pool_config.configuration_hash)
        end

        def test_url_sub_key_merges_correctly
          hash = { 'url' => 'abstract://foo?encoding=utf8&', 'adapter' => 'sqlite3', 'host' => 'bar', 'pool' => '3' }
          pool_config = resolve_db_config :production, 'production' => hash

          assert_equal({
            adapter:  'abstract',
            host:     'foo',
            encoding: 'utf8',
            pool:     '3'
          }, pool_config.configuration_hash)
        end

        def test_url_host_no_db
          pool_config = resolve_db_config 'abstract://foo?encoding=utf8'
          assert_equal({
            adapter:  'abstract',
            host:     'foo',
            encoding: 'utf8'
          }, pool_config.configuration_hash)
        end

        def test_url_missing_scheme
          assert_raises ActiveRecord::DatabaseConfigurations::InvalidConfigurationError do
            resolve_db_config 'foo'
          end
        end

        def test_url_host_db
          pool_config = resolve_db_config 'abstract://foo/bar?encoding=utf8'
          assert_equal({
            adapter:  'abstract',
            database: 'bar',
            host:     'foo',
            encoding: 'utf8'
          }, pool_config.configuration_hash)
        end

        def test_url_port
          pool_config = resolve_db_config 'abstract://foo:123?encoding=utf8'

          assert_equal({
            adapter:  'abstract',
            port:     123,
            host:     'foo',
            encoding: 'utf8'
          }, pool_config.configuration_hash)
        end

        def test_encoded_password
          password = 'am@z1ng_p@ssw0rd#!'
          encoded_password = URI.encode_www_form_component(password)
          pool_config = resolve_db_config "abstract://foo:#{encoded_password}@localhost/bar"

          assert_equal password, pool_config.configuration_hash[:password]
        end

        def test_url_with_authority_for_sqlite3
          pool_config = resolve_db_config 'sqlite3:///foo_test'

          assert_equal('/foo_test', pool_config.database)
        end

        def test_url_absolute_path_for_sqlite3
          pool_config = resolve_db_config 'sqlite3:/foo_test'

          assert_equal('/foo_test', pool_config.database)
        end

        def test_url_relative_path_for_sqlite3
          pool_config = resolve_db_config 'sqlite3:foo_test'

          assert_equal('foo_test', pool_config.database)
        end

        def test_url_memory_db_for_sqlite3
          pool_config = resolve_db_config 'sqlite3::memory:'
          assert_equal(':memory:', pool_config.database)
        end

        def test_url_sub_key_for_sqlite3
          pool_config = resolve_db_config :production, 'production' => { 'url' => 'sqlite3:foo?encoding=utf8' }

          assert_equal({
            adapter:  'sqlite3',
            database: 'foo',
            encoding: 'utf8'
          }, pool_config.configuration_hash)
        end

        def test_pool_config_with_invalid_type
          assert_raises TypeError do
            Base.connection_handler.establish_connection(Object.new)
          end
        end
      end
    end
  end
end
