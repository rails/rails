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
        assert_equal 'id', @cache.primary_keys['omgponies']
      end

      def test_primary_key_is_set_on_columns
        posts_columns = @cache.columns_hash['posts']
        assert posts_columns['id'].primary

        (posts_columns.keys - ['id']).each do |key|
          assert !posts_columns[key].primary
        end
      end

      def test_caches_columns
        columns = @cache.columns['posts']
        assert_equal columns, @cache.columns['posts']
      end

      def test_caches_columns_hash
        columns_hash = @cache.columns_hash['posts']
        assert_equal columns_hash, @cache.columns_hash['posts']
      end

      def test_clearing_column_cache
        @cache.columns['posts']
        @cache.columns_hash['posts']

        @cache.clear!

        assert_equal 0, @cache.columns.size
        assert_equal 0, @cache.columns_hash.size
      end
    end
  end
end
