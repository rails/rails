# frozen_string_literal: true

require "cases/helper"
require "active_support/core_ext/object/with"

module ActiveRecord
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase
      self.use_transactional_tests = false

      def setup
        @deduplicable_registries_were = deduplicable_classes.index_with do |klass|
          klass.registry.dup
        end
        @pool = ARUnit2Model.connection_pool
        @connection = ARUnit2Model.lease_connection
        @cache = new_bound_reflection
      end

      def teardown
        @deduplicable_registries_were.each do |klass, registry|
          klass.registry.clear
          klass.registry.merge!(registry)
        end
      end

      def new_bound_reflection(filename = nil)
        BoundSchemaReflection.new(SchemaReflection.new(filename), @pool)
      end

      def load_bound_reflection(filename)
        reset_deduplicable!
        new_bound_reflection(filename).tap do |cache|
          cache.load!
        end
      end

      def deduplicable_classes
        klasses = [
          ActiveRecord::ConnectionAdapters::SqlTypeMetadata,
          ActiveRecord::ConnectionAdapters::Column,
        ]

        if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL)
          klasses << ActiveRecord::ConnectionAdapters::PostgreSQL::TypeMetadata
        end
        if defined?(ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata)
          klasses << ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata
        end

        klasses.flat_map do |klass|
          [klass] + klass.descendants
        end.uniq
      end

      def reset_deduplicable!
        deduplicable_classes.each do |klass|
          klass.registry.clear
        end
      end

      def test_cached?
        cache = new_bound_reflection
        assert_not cache.cached?("courses")

        cache.columns("courses").size
        assert cache.cached?("courses")

        Tempfile.create(["schema_cache-", ".yml"]) do |tempfile|
          cache.dump_to(tempfile.path)

          reset_deduplicable!

          reflection = SchemaReflection.new(tempfile.path)

          # `check_schema_cache_dump_version` forces us to have an active connection
          # to load the cache.
          assert_not reflection.cached?("courses")

          # If we disable it we can load the cache
          SchemaReflection.with(check_schema_cache_dump_version: false) do
            assert reflection.cached?("courses")

            cache = BoundSchemaReflection.new(reflection, :__unused_pool__)
            assert cache.cached?("courses")
          end
        end
      end

      def test_cache_path_can_be_in_directory
        cache = new_bound_reflection
        tmp_dir = Dir.mktmpdir
        filename = File.join(tmp_dir, "schema.json")

        assert_not File.exist?(filename)
        assert cache.dump_to(filename)
        assert File.exist?(filename)
      ensure
        FileUtils.rm_r(tmp_dir)
      end

      def test_yaml_loads_5_1_dump
        cache = load_bound_reflection(schema_dump_5_1_path)

        assert_no_queries do
          assert_equal 11, cache.columns("posts").size
          assert_equal 11, cache.columns_hash("posts").size
          assert cache.data_source_exists?("posts")
          assert_equal "id", cache.primary_keys("posts")
        end
      end

      def test_yaml_loads_5_1_dump_without_indexes_still_queries_for_indexes
        cache = load_bound_reflection(schema_dump_5_1_path)

        assert_queries_count(include_schema: true) do
          assert_equal 1, cache.indexes("courses").size
        end
      end

      def test_primary_key_for_existent_table
        assert_equal "id", @cache.primary_keys("courses")
      end

      def test_primary_key_for_non_existent_table
        assert_nil @cache.primary_keys("omgponies")
      end

      def test_columns_for_existent_table
        assert_equal 3, @cache.columns("courses").size
      end

      def test_columns_for_non_existent_table
        assert_raises ActiveRecord::StatementInvalid do
          @cache.columns("omgponies")
        end
      end

      def test_columns_hash_for_existent_table
        assert_equal 3, @cache.columns_hash("courses").size
      end

      def test_columns_hash_for_non_existent_table
        assert_raises ActiveRecord::StatementInvalid do
          @cache.columns_hash("omgponies")
        end
      end

      def test_indexes_for_existent_table
        assert_equal 1, @cache.indexes("courses").size
      end

      def test_indexes_for_non_existent_table
        assert_equal [], @cache.indexes("omgponies")
      end

      def test_clearing
        @cache.columns("courses")
        @cache.columns_hash("courses")
        @cache.data_source_exists?("courses")
        @cache.primary_keys("courses")
        @cache.indexes("courses")

        @cache.clear!

        assert_equal 0, @cache.size
      end

      def test_insert_uses_schema_cache_for_primary_key
        # First call might need to populate the schema cache
        @connection.insert("INSERT INTO courses (name) VALUES ('Prepopulate')")

        # With cache available, insert should not make additional schema queries
        assert_queries_count(1, include_schema: true) do
          @connection.insert("INSERT INTO courses (name) VALUES ('INSERT only')")
        end
      end

      def test_marshal_dump_and_load_with_ignored_tables
        assert_not ActiveRecord.schema_cache_ignored_table?("professors")

        ActiveRecord.with(schema_cache_ignored_tables: ["professors"]) do
          assert ActiveRecord.schema_cache_ignored_table?("professors")
          # Create an empty cache.
          cache = new_bound_reflection

          Tempfile.create(["schema_cache-", ".dump"]) do |tempfile|
            # Dump it. It should get populated before dumping.
            cache.dump_to(tempfile.path)

            # Load a new cache.
            cache = load_bound_reflection(tempfile.path)

            # Assert a table in the cache
            assert cache.data_source_exists?("courses"), "expected posts to be in the cached data_sources"
            assert_equal 3, cache.columns("courses").size
            assert_equal 3, cache.columns_hash("courses").size
            assert cache.data_source_exists?("courses")
            assert_equal "id", cache.primary_keys("courses")
            assert_equal 1, cache.indexes("courses").size

            # Assert ignored table. Behavior should match non-existent table.
            assert_nil cache.data_source_exists?("professors"), "expected comments to not be in the cached data_sources"
            assert_raises ActiveRecord::StatementInvalid do
              cache.columns("professors")
            end
            assert_raises ActiveRecord::StatementInvalid do
              cache.columns_hash("professors").size
            end
            assert_nil cache.primary_keys("professors")
            assert_equal [], cache.indexes("professors")
          end
        end
      end

      def test_gzip_dumps_identical
        # Create an empty cache.
        cache = new_bound_reflection

        Tempfile.create(["schema_cache-", ".yml.gz"]) do |tempfile_a|
          # Dump it. It should get populated before dumping.
          cache.dump_to(tempfile_a.path)
          digest_a = Digest::MD5.file(tempfile_a).hexdigest

          sleep(1) # ensure timestamp changes

          Tempfile.create(["schema_cache-", ".yml.gz"]) do |tempfile_b|
            # Dump it. It should get populated before dumping.
            cache.dump_to(tempfile_b.path)
            digest_b = Digest::MD5.file(tempfile_b).hexdigest


            assert_equal digest_a, digest_b
          end
        end
      end

      def test_data_source_exist
        assert @cache.data_source_exists?("courses")
        assert_not @cache.data_source_exists?("foo")
      end

      def test_clear_data_source_cache
        # Cache data sources list.
        assert @cache.data_source_exists?("courses")

        @cache.clear_data_source_cache!("courses")
        assert_queries_count(1, include_schema: true) do
          @cache.data_source_exists?("courses")
        end
      end

      test "#columns_hash? is populated by #columns_hash" do
        assert_not @cache.columns_hash?("courses")

        @cache.columns_hash("courses")

        assert @cache.columns_hash?("courses")
      end

      test "#columns_hash? is not populated by #data_source_exists?" do
        assert_not @cache.columns_hash?("courses")

        @cache.data_source_exists?("courses")

        assert_not @cache.columns_hash?("courses")
      end

      unless in_memory_db?
        def test_when_lazily_load_schema_cache_is_set_cache_is_lazily_populated_when_est_connection
          Tempfile.create(["schema_cache-", ".yml"]) do |tempfile|
            original_config = ActiveRecord::Base.configurations.configs_for(env_name: "arunit2", name: "primary")
            new_config = original_config.configuration_hash.merge(schema_cache_path: tempfile.path)

            ActiveRecord::Base.establish_connection(new_config)

            # cache starts empty
            assert_nil ActiveRecord::Base.connection_pool.schema_reflection.instance_variable_get(:@cache)

            # now we access the cache, causing it to load
            assert_not_nil ActiveRecord::Base.schema_cache.version

            assert File.exist?(tempfile)
            assert_not_nil ActiveRecord::Base.connection_pool.schema_reflection.instance_variable_get(:@cache)

            # assert cache is still empty on new connection (precondition for the
            # following to show it is loading because of the config change)
            ActiveRecord::Base.establish_connection(new_config)

            assert File.exist?(tempfile)
            assert_nil ActiveRecord::Base.connection_pool.schema_reflection.instance_variable_get(:@cache)

            # cache is loaded upon connection when lazily loading is on
            ActiveRecord.with(lazily_load_schema_cache: true) do
              ActiveRecord::Base.establish_connection(new_config)
              ActiveRecord::Base.connection_pool.lease_connection.verify!

              assert File.exist?(tempfile)
              assert_not_nil ActiveRecord::Base.connection_pool.schema_reflection.instance_variable_get(:@cache)
            end
          end
        ensure
          ActiveRecord::Base.establish_connection(:arunit)
        end
      end

      test "#init_with skips deduplication if told to" do
        coder = {
          "columns" => [].freeze,
          "deduplicated" => true,
        }

        schema_cache = SchemaCache.allocate
        schema_cache.init_with(coder)
        assert_same coder["columns"], schema_cache.instance_variable_get(:@columns)
      end

      test "#encode_with sorts members" do
        values = [["z", nil], ["y", nil], ["x", nil]]
        expected = values.sort.to_h

        named = Struct.new(:name)
        named_values = [["z", [named.new("c"), named.new("b")]], ["y", [named.new("c"), named.new("b")]], ["x", [named.new("c"), named.new("b")]]]
        named_expected = named_values.sort.to_h.transform_values { _1.sort_by(&:name) }

        coder = {
          "columns" => named_values,
          "primary_keys" => values,
          "data_sources" => values,
          "indexes" => named_values,
          "deduplicated" => true
        }

        schema_cache = SchemaCache.allocate
        schema_cache.init_with(coder)
        schema_cache.encode_with(coder)

        assert_equal named_expected, coder["columns"]
        assert_equal expected, coder["primary_keys"]
        assert_equal expected, coder["data_sources"]
        assert_equal named_expected, coder["indexes"]
        assert coder.key?("version")
      end

      private
        def schema_dump_5_1_path
          "#{ASSETS_ROOT}/schema_dump_5_1.yml"
        end
    end

    module DumpAndLoadTests
      def setup
        @pool = ARUnit2Model.connection_pool

        @deduplicable_registries_were = deduplicable_classes.index_with do |klass|
          klass.registry.dup
        end
      end

      def teardown
        @deduplicable_registries_were.each do |klass, registry|
          klass.registry.clear
          klass.registry.merge!(registry)
        end
      end

      def test_dump_and_load_via_disk
        # Create an empty cache.
        cache = new_bound_reflection

        Tempfile.create(["schema_cache-", format_extension]) do |tempfile|
          # Dump it. It should get populated before dumping.
          cache.dump_to(tempfile.path)

          # Load a new cache.
          cache = load_bound_reflection(tempfile.path)

          assert_no_queries(include_schema: true) do
            assert_equal 3, cache.columns("courses").size
            assert_equal 3, cache.columns("courses").map { |column| column.cast_type }.compact.size
            assert_equal 3, cache.columns_hash("courses").size
            assert cache.data_source_exists?("courses")
            assert_equal "id", cache.primary_keys("courses")
            assert_equal 1, cache.indexes("courses").size
          end
        end
      end

      def test_dump_and_load_with_gzip
        # Create an empty cache.
        cache = new_bound_reflection

        Tempfile.create(["schema_cache-", "#{format_extension}.gz"]) do |tempfile|
          # Dump it. It should get populated before dumping.
          cache.dump_to(tempfile.path)

          reset_deduplicable!

          # Unzip and load manually.
          cache = Zlib::GzipReader.open(tempfile.path) { |gz| load(gz.read) }

          assert_no_queries(include_schema: true) do
            assert_equal 3, cache.columns(@pool, "courses").size
            assert_equal 3, cache.columns(@pool, "courses").map { |column| column.cast_type }.compact.size
            assert_equal 3, cache.columns_hash(@pool, "courses").size
            assert cache.data_source_exists?(@pool, "courses")
            assert_equal "id", cache.primary_keys(@pool, "courses")
            assert_equal 1, cache.indexes(@pool, "courses").size
          end

          # Load the cache the usual way.
          cache = load_bound_reflection(tempfile.path)

          assert_no_queries(include_schema: true) do
            assert_equal 3, cache.columns("courses").size
            assert_equal 3, cache.columns("courses").map { |column| column.cast_type }.compact.size
            assert_equal 3, cache.columns_hash("courses").size
            assert cache.data_source_exists?("courses")
            assert_equal "id", cache.primary_keys("courses")
            assert_equal 1, cache.indexes("courses").size
          end
        end
      end

      private
        def new_bound_reflection(filename = nil)
          BoundSchemaReflection.new(SchemaReflection.new(filename), @pool)
        end

        def load_bound_reflection(filename)
          reset_deduplicable!

          new_bound_reflection(filename).tap do |cache|
            cache.load!
          end
        end

        def deduplicable_classes
          klasses = [
            ActiveRecord::ConnectionAdapters::SqlTypeMetadata,
            ActiveRecord::ConnectionAdapters::Column,
          ]

          if defined?(ActiveRecord::ConnectionAdapters::PostgreSQL)
            klasses << ActiveRecord::ConnectionAdapters::PostgreSQL::TypeMetadata
          end
          if defined?(ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata)
            klasses << ActiveRecord::ConnectionAdapters::MySQL::TypeMetadata
          end

          klasses.flat_map do |klass|
            [klass] + klass.descendants
          end.uniq
        end

        def reset_deduplicable!
          deduplicable_classes.each do |klass|
            klass.registry.clear
          end
        end
    end

    class MarshalFormatTest < ActiveRecord::TestCase
      include DumpAndLoadTests

      private
        def format_extension
          ".dump"
        end

        def load(data)
          Marshal.load(data)
        end
    end

    class YamlFormatTest < ActiveRecord::TestCase
      include DumpAndLoadTests

      private
        def format_extension
          ".yml"
        end

        def load(data)
          YAML.unsafe_load(data)
        end
    end
  end
end
