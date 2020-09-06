# frozen_string_literal: true

require 'cases/helper'

module ActiveRecord
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase
      def setup
        @connection       = ActiveRecord::Base.connection
        @cache            = SchemaCache.new @connection
        @database_version = @connection.get_database_version
      end

      def test_primary_key
        assert_equal 'id', @cache.primary_keys('posts')
      end

      def test_yaml_dump_and_load
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(['schema_cache-', '.yml'])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load the cache.
        cache = SchemaCache.load_from(tempfile.path)

        # Give it a connection. Usually the connection
        # would get set on the cache when it's retrieved
        # from the pool.
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_yaml_dump_and_load_with_gzip
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(['schema_cache-', '.yml.gz'])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Unzip and load manually.
        cache = Zlib::GzipReader.open(tempfile.path) { |gz| YAML.load(gz.read) }

        # Give it a connection. Usually the connection
        # would get set on the cache when it's retrieved
        # from the pool.
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end

        # Load the cache the usual way.
        cache = SchemaCache.load_from(tempfile.path)

        # Give it a connection.
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_yaml_loads_5_1_dump
        cache = SchemaCache.load_from(schema_dump_path)
        cache.connection = @connection

        assert_no_queries do
          assert_equal 11, cache.columns('posts').size
          assert_equal 11, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
        end
      end

      def test_yaml_loads_5_1_dump_without_indexes_still_queries_for_indexes
        cache = SchemaCache.load_from(schema_dump_path)
        cache.connection = @connection

        assert_queries :any, ignore_none: true do
          assert_equal 1, cache.indexes('posts').size
        end
      end

      def test_yaml_loads_5_1_dump_without_database_version_still_queries_for_database_version
        cache = SchemaCache.load_from(schema_dump_path)
        cache.connection = @connection

        # We can't verify queries get executed because the database version gets
        # cached in both MySQL and PostgreSQL outside of the schema cache.
        assert_nil cache.instance_variable_get(:@database_version)
        assert_equal @database_version.to_s, cache.database_version.to_s
      end

      def test_primary_key_for_non_existent_table
        assert_nil @cache.primary_keys('omgponies')
      end

      def test_caches_columns
        columns = @cache.columns('posts')
        assert_equal columns, @cache.columns('posts')
      end

      def test_caches_columns_hash
        columns_hash = @cache.columns_hash('posts')
        assert_equal columns_hash, @cache.columns_hash('posts')
      end

      def test_caches_indexes
        indexes = @cache.indexes('posts')
        assert_equal indexes, @cache.indexes('posts')
      end

      def test_caches_database_version
        @cache.database_version # cache database_version

        assert_no_queries do
          assert_equal @database_version.to_s, @cache.database_version.to_s

          if current_adapter?(:Mysql2Adapter)
            assert_not_nil @cache.database_version.full_version_string
          end
        end
      end

      def test_clearing
        @cache.columns('posts')
        @cache.columns_hash('posts')
        @cache.data_sources('posts')
        @cache.primary_keys('posts')
        @cache.indexes('posts')

        @cache.clear!

        assert_equal 0, @cache.size
        assert_nil @cache.instance_variable_get(:@database_version)
      end

      def test_marshal_dump_and_load
        # Create an empty cache.
        cache = SchemaCache.new @connection

        # Populate it.
        cache.add('posts')

        # Create a new cache by marchal dumping / loading.
        cache = Marshal.load(Marshal.dump(cache))

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      end

      def test_marshal_dump_and_load_via_disk
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(['schema_cache-', '.dump'])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache.
        cache = SchemaCache.load_from(tempfile.path)
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_marshal_dump_and_load_with_gzip
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(['schema_cache-', '.dump.gz'])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache manually.
        cache = Zlib::GzipReader.open(tempfile.path) { |gz| Marshal.load(gz.read) }
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end

        # Load a new cache.
        cache = SchemaCache.load_from(tempfile.path)
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns('posts').size
          assert_equal 12, cache.columns_hash('posts').size
          assert cache.data_sources('posts')
          assert_equal 'id', cache.primary_keys('posts')
          assert_equal 1, cache.indexes('posts').size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_data_source_exist
        assert @cache.data_source_exists?('posts')
        assert_not @cache.data_source_exists?('foo')
      end

      def test_clear_data_source_cache
        @cache.clear_data_source_cache!('posts')
      end

      test '#columns_hash? is populated by #columns_hash' do
        assert_not @cache.columns_hash?('posts')

        @cache.columns_hash('posts')

        assert @cache.columns_hash?('posts')
      end

      test '#columns_hash? is not populated by #data_source_exists?' do
        assert_not @cache.columns_hash?('posts')

        @cache.data_source_exists?('posts')

        assert_not @cache.columns_hash?('posts')
      end

      private
        def schema_dump_path
          "#{ASSETS_ROOT}/schema_dump_5_1.yml"
        end
    end
  end
end
