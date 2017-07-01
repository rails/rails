require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase
      def setup
        connection = ActiveRecord::Base.connection
        @cache     = SchemaCache.new connection
      end

      def test_primary_key
        assert_equal "id", @cache.primary_keys("posts")
      end

      def test_yaml_dump_and_load
        @cache.columns("posts")
        @cache.columns_hash("posts")
        @cache.data_sources("posts")
        @cache.primary_keys("posts")

        new_cache = YAML.load(YAML.dump(@cache))
        assert_no_queries do
          assert_equal 11, new_cache.columns("posts").size
          assert_equal 11, new_cache.columns_hash("posts").size
          assert new_cache.data_sources("posts")
          assert_equal "id", new_cache.primary_keys("posts")
        end
      end

      def test_yaml_loads_5_1_dump
        body = File.open(schema_dump_path).read
        cache = YAML.load(body)

        assert_no_queries do
          assert_equal 11, cache.columns("posts").size
          assert_equal 11, cache.columns_hash("posts").size
          assert cache.data_sources("posts")
          assert_equal "id", cache.primary_keys("posts")
        end
      end

      def test_primary_key_for_non_existent_table
        assert_nil @cache.primary_keys("omgponies")
      end

      def test_caches_columns
        columns = @cache.columns("posts")
        assert_equal columns, @cache.columns("posts")
      end

      def test_caches_columns_hash
        columns_hash = @cache.columns_hash("posts")
        assert_equal columns_hash, @cache.columns_hash("posts")
      end

      def test_clearing
        @cache.columns("posts")
        @cache.columns_hash("posts")
        @cache.data_sources("posts")
        @cache.primary_keys("posts")

        @cache.clear!

        assert_equal 0, @cache.size
      end

      def test_dump_and_load
        @cache.columns("posts")
        @cache.columns_hash("posts")
        @cache.data_sources("posts")
        @cache.primary_keys("posts")

        @cache = Marshal.load(Marshal.dump(@cache))

        assert_no_queries do
          assert_equal 11, @cache.columns("posts").size
          assert_equal 11, @cache.columns_hash("posts").size
          assert @cache.data_sources("posts")
          assert_equal "id", @cache.primary_keys("posts")
        end
      end

      def test_data_source_exist
        assert @cache.data_source_exists?("posts")
        assert_not @cache.data_source_exists?("foo")
      end

      def test_clear_data_source_cache
        @cache.clear_data_source_cache!("posts")
      end

      private

        def schema_dump_path
          "test/assets/schema_dump_5_1.yml"
        end
    end
  end
end
