# frozen_string_literal: true

require "cases/helper"

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
        @check_schema_cache_dump_version_was = SchemaReflection.check_schema_cache_dump_version
      end

      def teardown
        SchemaReflection.check_schema_cache_dump_version = @check_schema_cache_dump_version_was
        @deduplicable_registries_were.each do |klass, registry|
          klass.registry.clear
          klass.registry.merge!(registry)
        end
      end

      def new_bound_reflection(pool = @pool)
        BoundSchemaReflection.new(SchemaReflection.new(nil), pool)
      end

      def load_bound_reflection(filename, pool = @pool)
        reset_deduplicable!
        BoundSchemaReflection.new(SchemaReflection.new(filename), pool).tap do |cache|
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

        tempfile = Tempfile.new(["schema_cache-", ".yml"])
        cache.dump_to(tempfile.path)

        reset_deduplicable!

        reflection = SchemaReflection.new(tempfile.path)

        # `check_schema_cache_dump_version` forces us to have an active connection
        # to load the cache.
        assert_not reflection.cached?("courses")

        # If we disable it we can load the cache
        SchemaReflection.check_schema_cache_dump_version = false
        assert reflection.cached?("courses")

        cache = BoundSchemaReflection.new(reflection, :__unused_pool__)
        assert cache.cached?("courses")
      end

      def test_yaml_dump_and_load
        # Create an empty cache.
        cache = new_bound_reflection

        tempfile = Tempfile.new(["schema_cache-", ".yml"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        reset_deduplicable!

        # Load the cache.
        cache = load_bound_reflection(tempfile.path)

        assert_no_queries(include_schema: true) do
          assert_equal 3, cache.columns("courses").size
          assert_equal 3, cache.columns("courses").map { |column| column.fetch_cast_type(@connection) }.compact.size
          assert_equal 3, cache.columns_hash("courses").size
          assert cache.data_source_exists?("courses")
          assert_equal "id", cache.primary_keys("courses")
          assert_equal 1, cache.indexes("courses").size
        end
      ensure
        tempfile.unlink
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

      def test_yaml_dump_and_load_with_gzip
        # Create an empty cache.
        cache = new_bound_reflection

        tempfile = Tempfile.new(["schema_cache-", ".yml.gz"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        reset_deduplicable!

        # Unzip and load manually.
        cache = Zlib::GzipReader.open(tempfile.path) do |gz|
          YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(gz.read) : YAML.load(gz.read)
        end

        assert_no_queries(include_schema: true) do
          assert_equal 3, cache.columns(@connection, "courses").size
          assert_equal 3, cache.columns(@connection, "courses").map { |column| column.fetch_cast_type(@connection) }.compact.size
          assert_equal 3, cache.columns_hash(@connection, "courses").size
          assert cache.data_source_exists?(@connection, "courses")
          assert_equal "id", cache.primary_keys(@connection, "courses")
          assert_equal 1, cache.indexes(@connection, "courses").size
        end

        # Load the cache the usual way.
        cache = load_bound_reflection(tempfile.path)

        assert_no_queries do
          assert_equal 3, cache.columns("courses").size
          assert_equal 3, cache.columns_hash("courses").size
          assert cache.data_source_exists?("courses")
          assert_equal "id", cache.primary_keys("courses")
          assert_equal 1, cache.indexes("courses").size
        end
      ensure
        tempfile.unlink
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

      def test_yaml_load_8_0_dump_without_cast_type_still_get_the_right_one
        cache = load_bound_reflection(schema_dump_8_0_path)

        if current_adapter?(:PostgreSQLAdapter)
          assert_queries_count(include_schema: true) do
            columns = cache.columns_hash("courses")
            assert_equal 3, columns.size
            cast_type = columns["name"].fetch_cast_type(@connection)
            assert_not_nil cast_type, "expected cast_type to be present"
            assert_equal :string, cast_type.type
          end
        else
          assert_no_queries do
            columns = cache.columns_hash("courses")
            assert_equal 3, columns.size
            cast_type = columns["name"].fetch_cast_type(@connection)
            assert_not_nil cast_type, "expected cast_type to be present"
            assert_equal :string, cast_type.type
          end
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

      def test_marshal_dump_and_load
        # Create an empty cache.
        cache = new_bound_reflection

        # Populate it.
        cache.add("courses")

        # Create a new cache by marshal dumping / loading.
        cache = Marshal.load(Marshal.dump(cache.instance_variable_get(:@schema_reflection).instance_variable_get(:@cache)))

        assert_no_queries do
          assert_equal 3, cache.columns(@connection, "courses").size
          assert_equal 3, cache.columns_hash(@connection, "courses").size
          assert cache.data_source_exists?(@connection, "courses")
          assert_equal "id", cache.primary_keys(@connection, "courses")
          assert_equal 1, cache.indexes(@connection, "courses").size
        end
      end

      def test_marshal_dump_and_load_via_disk
        # Create an empty cache.
        cache = new_bound_reflection

        tempfile = Tempfile.new(["schema_cache-", ".dump"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache.
        cache = load_bound_reflection(tempfile.path)

        assert_no_queries do
          assert_equal 3, cache.columns("courses").size
          assert_equal 3, cache.columns_hash("courses").size
          assert cache.data_source_exists?("courses")
          assert_equal "id", cache.primary_keys("courses")
          assert_equal 1, cache.indexes("courses").size
        end
      ensure
        tempfile.unlink
      end

      def test_marshal_dump_and_load_with_ignored_tables
        old_ignore = ActiveRecord.schema_cache_ignored_tables
        assert_not ActiveRecord.schema_cache_ignored_table?("professors")
        ActiveRecord.schema_cache_ignored_tables = ["professors"]
        assert ActiveRecord.schema_cache_ignored_table?("professors")
        # Create an empty cache.
        cache = new_bound_reflection

        tempfile = Tempfile.new(["schema_cache-", ".dump"])
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
      ensure
        tempfile.unlink
        ActiveRecord.schema_cache_ignored_tables = old_ignore
      end

      def test_marshal_dump_and_load_with_gzip
        # Create an empty cache.
        cache = new_bound_reflection

        tempfile = Tempfile.new(["schema_cache-", ".dump.gz"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile.path)

        # Load a new cache manually.
        cache = Zlib::GzipReader.open(tempfile.path) { |gz| Marshal.load(gz.read) }

        assert_no_queries do
          assert_equal 3, cache.columns(@connection, "courses").size
          assert_equal 3, cache.columns_hash(@connection, "courses").size
          assert cache.data_source_exists?(@connection, "courses")
          assert_equal "id", cache.primary_keys(@connection, "courses")
          assert_equal 1, cache.indexes(@connection, "courses").size
        end

        # Load a new cache.
        cache = load_bound_reflection(tempfile.path)

        assert_no_queries do
          assert_equal 3, cache.columns("courses").size
          assert_equal 3, cache.columns_hash("courses").size
          assert cache.data_source_exists?("courses")
          assert_equal "id", cache.primary_keys("courses")
          assert_equal 1, cache.indexes("courses").size
        end
      ensure
        tempfile.unlink
      end

      def test_gzip_dumps_identical
        # Create an empty cache.
        cache = new_bound_reflection

        tempfile_a = Tempfile.new(["schema_cache-", ".yml.gz"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile_a.path)
        digest_a = Digest::MD5.file(tempfile_a).hexdigest
        sleep(1) # ensure timestamp changes
        tempfile_b = Tempfile.new(["schema_cache-", ".yml.gz"])
        # Dump it. It should get populated before dumping.
        cache.dump_to(tempfile_b.path)
        digest_b = Digest::MD5.file(tempfile_b).hexdigest


        assert_equal digest_a, digest_b
      ensure
        tempfile_a.unlink
        tempfile_b.unlink
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
          tempfile = Tempfile.new(["schema_cache-", ".yml"])
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
          old_config = ActiveRecord.lazily_load_schema_cache
          ActiveRecord.lazily_load_schema_cache = true
          ActiveRecord::Base.establish_connection(new_config)
          ActiveRecord::Base.connection_pool.lease_connection.verify!

          assert File.exist?(tempfile)
          assert_not_nil ActiveRecord::Base.connection_pool.schema_reflection.instance_variable_get(:@cache)
        ensure
          ActiveRecord.lazily_load_schema_cache = old_config
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

        coder = {
          "columns" => values,
          "primary_keys" => values,
          "data_sources" => values,
          "indexes" => values,
          "deduplicated" => true
        }

        schema_cache = SchemaCache.allocate
        schema_cache.init_with(coder)
        schema_cache.encode_with(coder)

        assert_equal expected, coder["columns"]
        assert_equal expected, coder["primary_keys"]
        assert_equal expected, coder["data_sources"]
        assert_equal expected, coder["indexes"]
        assert coder.key?("version")
      end

      private
        def schema_dump_5_1_path
          "#{ASSETS_ROOT}/schema_dump_5_1.yml"
        end

        def schema_dump_8_0_path
          "#{ASSETS_ROOT}/schema_dump_8_0.yml"
        end
    end
  end
end
