# frozen_string_literal: true

require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase
      def setup
        @connection       = ActiveRecord::Base.connection
        @cache            = SchemaCache.new @connection
        @database_version = @connection.get_database_version
      end

      def test_yaml_dump_and_load
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(["schema_cache-", ".yml"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load the cache.
        cache = SchemaCache.load_from(tempfile.path)

        # Give it a connection. Usually the connection
        # would get set on the cache when it's retrieved
        # from the pool.
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_cache_path_can_be_in_directory
        cache = SchemaCache.new @connection
        filename = "some_dir/schema.json"
        assert cache.dump_to(filename)
      ensure
        File.delete(filename)
      end

      def test_yaml_dump_and_load_with_gzip
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(["schema_cache-", ".yml.gz"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Unzip and load manually.
        cache = Zlib::GzipReader.open(tempfile.path) do |gz|
          YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(gz.read) : YAML.load(gz.read)
        end

        # Give it a connection. Usually the connection
        # would get set on the cache when it's retrieved
        # from the pool.
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end

        # Load the cache the usual way.
        cache = SchemaCache.load_from(tempfile.path)

        # Give it a connection.
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_yaml_loads_5_1_dump
        cache = SchemaCache.load_from(schema_dump_path)
        cache.connection = @connection

        assert_no_queries do
          assert_equal 11, cache.columns("posts").size
          assert_equal 11, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
        end
      end

      def test_yaml_loads_5_1_dump_without_indexes_still_queries_for_indexes
        cache = SchemaCache.load_from(schema_dump_path)
        cache.connection = @connection

        assert_queries :any, ignore_none: true do
          assert_equal 1, cache.indexes("posts").size
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

      def test_primary_key_for_existent_table
        assert_equal "id", @cache.primary_keys("posts")
      end

      def test_primary_key_for_non_existent_table
        assert_nil @cache.primary_keys("omgponies")
      end

      def test_columns_for_existent_table
        assert_equal 12, @cache.columns("posts").size
      end

      def test_columns_for_non_existent_table
        assert_raises ActiveRecord::StatementInvalid do
          @cache.columns("omgponies")
        end
      end

      def test_columns_hash_for_existent_table
        assert_equal 12, @cache.columns_hash("posts").size
      end

      def test_columns_hash_for_non_existent_table
        assert_raises ActiveRecord::StatementInvalid do
          @cache.columns_hash("omgponies")
        end
      end

      def test_indexes_for_existent_table
        assert_equal 1, @cache.indexes("posts").size
      end

      def test_indexes_for_non_existent_table
        assert_equal [], @cache.indexes("omgponies")
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
        @cache.columns("posts")
        @cache.columns_hash("posts")
        @cache.data_sources("posts")
        @cache.primary_keys("posts")
        @cache.indexes("posts")

        @cache.clear!

        assert_equal 0, @cache.size
        assert_nil @cache.instance_variable_get(:@database_version)
      end

      def test_marshal_dump_and_load
        # Create an empty cache.
        cache = SchemaCache.new @connection

        # Populate it.
        cache.add("posts")

        # Create a new cache by marshal dumping / loading.
        cache = Marshal.load(Marshal.dump(cache))

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      end

      def test_marshal_dump_and_load_via_disk
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(["schema_cache-", ".dump"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache.
        cache = SchemaCache.load_from(tempfile.path)
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_marshal_dump_and_load_with_ignored_tables
        old_ignore = ActiveRecord.schema_cache_ignored_tables
        ActiveRecord.schema_cache_ignored_tables = ["p_schema_migrations"]
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(["schema_cache-", ".dump"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache.
        cache = SchemaCache.load_from(tempfile.path)
        cache.connection = @connection

        # Assert a table in the cache
        assert cache.data_sources("posts"), "expected posts to be in the cached data_sources"
        assert_equal 12, cache.columns("posts").size
        assert_equal 12, cache.columns_hash("posts").size
        assert cache.data_sources("posts")
        assert_equal "id", cache.primary_keys("posts")
        assert_equal 1, cache.indexes("posts").size

        # Assert ignored table. Behavior should match non-existent table.
        assert_nil cache.data_sources("p_schema_migrations"), "expected comments to not be in the cached data_sources"
        assert_raises ActiveRecord::StatementInvalid do
          cache.columns("p_schema_migrations")
        end
        assert_raises ActiveRecord::StatementInvalid do
          cache.columns_hash("p_schema_migrations").size
        end
        assert_nil cache.primary_keys("p_schema_migrations")
        assert_equal [], cache.indexes("p_schema_migrations")
      ensure
        tempfile.unlink
        ActiveRecord.schema_cache_ignored_tables = old_ignore
      end

      def test_marshal_dump_and_load_with_gzip
        # Create an empty cache.
        cache = SchemaCache.new @connection

        tempfile = Tempfile.new(["schema_cache-", ".dump.gz"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache manually.
        cache = Zlib::GzipReader.open(tempfile.path) { |gz| Marshal.load(gz.read) }
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end

        # Load a new cache.
        cache = SchemaCache.load_from(tempfile.path)
        cache.connection = @connection

        assert_no_queries do
          assert_equal 12, cache.columns("posts").size
          assert_equal 12, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
          assert_equal 1, cache.indexes("posts").size
          assert_equal @database_version.to_s, cache.database_version.to_s
        end
      ensure
        tempfile.unlink
      end

      def test_data_source_exist
        assert @cache.data_source_exists?("posts")
        assert_not @cache.data_source_exists?("foo")
      end

      def test_clear_data_source_cache
        @cache.clear_data_source_cache!("posts")
      end

      test "#columns_hash? is populated by #columns_hash" do
        assert_not @cache.columns_hash?("posts")

        @cache.columns_hash("posts")

        assert @cache.columns_hash?("posts")
      end

      test "#columns_hash? is not populated by #data_source_exists?" do
        assert_not @cache.columns_hash?("posts")

        @cache.data_source_exists?("posts")

        assert_not @cache.columns_hash?("posts")
      end

      unless in_memory_db?
        def test_when_lazily_load_schema_cache_is_set_cache_is_lazily_populated_when_est_connection
          tempfile = Tempfile.new(["schema_cache-", ".yml"])
          original_config = ActiveRecord::Base.connection_db_config
          new_config = original_config.configuration_hash.merge(schema_cache_path: tempfile.path)

          ActiveRecord::Base.establish_connection(new_config)

          # cache is empty
          assert_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@primary_keys)
          assert_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@data_sources)
          assert_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@indexes)

          # calling dump_to will load data sources, but not the rest of the cache
          # so we need to set the cache manually. This essentially mimics the behavior
          # of the Railtie.
          cache = SchemaCache.new(ActiveRecord::Base.connection)
          cache.dump_to(tempfile.path)
          ActiveRecord::Base.connection.schema_cache = cache

          assert File.exist?(tempfile)
          assert_not_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@primary_keys)
          assert_not_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@data_sources)
          assert_not_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@indexes)

          # assert cache is empty on new connection
          ActiveRecord::Base.establish_connection(new_config)

          assert File.exist?(tempfile)
          assert_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@primary_keys)
          assert_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@data_sources)
          assert_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@indexes)

          # cache is lazily loaded when lazily loading is on
          old_config = ActiveRecord.lazily_load_schema_cache
          ActiveRecord.lazily_load_schema_cache = true
          ActiveRecord::Base.establish_connection(new_config)

          assert File.exist?(tempfile)
          assert_not_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@primary_keys)
          assert_not_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@data_sources)
          assert_not_empty ActiveRecord::Base.connection.schema_cache.instance_variable_get(:@indexes)
        ensure
          ActiveRecord.lazily_load_schema_cache = old_config
          ActiveRecord::Base.establish_connection(:arunit)
        end
      end

      private
        def schema_dump_path
          "#{ASSETS_ROOT}/schema_dump_5_1.yml"
        end
    end
  end
end
