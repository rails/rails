require "cases/helper"

module ActiveRecord
  module ConnectionAdapters
    class SchemaCacheTest < ActiveRecord::TestCase
      def setup
        connection = ActiveRecord::Base.connection
        @cache     = SchemaCache.new connection
      end

      def test_primary_key
        assert_equal 'id', @cache.primary_keys['posts']
      end

      def test_primary_key_for_non_existent_table
        assert_nil @cache.primary_keys['omgponies']
      end

      def test_caches_columns
        columns = @cache.columns['posts']
        assert_equal columns, @cache.columns['posts']
      end

      def test_caches_columns_hash
        columns_hash = @cache.columns_hash['posts']
        assert_equal columns_hash, @cache.columns_hash['posts']
      end

      def test_clearing
        @cache.columns['posts']
        @cache.columns_hash['posts']
        @cache.tables['posts']
        @cache.primary_keys['posts']

        @cache.clear!

        assert_equal 0, @cache.columns.size
        assert_equal 0, @cache.columns_hash.size
        assert_equal 0, @cache.tables.size
        assert_equal 0, @cache.primary_keys.size
      end

      def test_dump_and_load
        @cache.columns['posts']
        @cache.columns_hash['posts']
        @cache.tables['posts']
        @cache.primary_keys['posts']

        @cache = Marshal.load(Marshal.dump(@cache))

        assert_equal 12, @cache.columns['posts'].size
        assert_equal 12, @cache.columns_hash['posts'].size
        assert @cache.tables['posts']
        assert_equal 'id', @cache.primary_keys['posts']
      end

    end
  end
end
