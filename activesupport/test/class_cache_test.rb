require 'abstract_unit'
require 'active_support/dependencies'

module ActiveSupport
  module Dependencies
    class ClassCacheTest < ActiveSupport::TestCase
      def setup
        @cache = ClassCache.new
      end

      def test_empty?
        assert @cache.empty?
        @cache[ClassCacheTest] = ClassCacheTest
        assert !@cache.empty?
      end

      def test_clear!
        assert @cache.empty?
        @cache[ClassCacheTest] = ClassCacheTest
        assert !@cache.empty?
        @cache.clear!
        assert @cache.empty?
      end

      def test_set_key
        @cache[ClassCacheTest] = ClassCacheTest
        assert @cache.key?(ClassCacheTest.name)
      end

      def test_set_rejects_strings
        @cache[ClassCacheTest.name] = ClassCacheTest
        assert @cache.empty?
      end

      def test_get_with_class
        @cache[ClassCacheTest] = ClassCacheTest
        assert_equal ClassCacheTest, @cache[ClassCacheTest]
      end

      def test_get_with_name
        @cache[ClassCacheTest] = ClassCacheTest
        assert_equal ClassCacheTest, @cache[ClassCacheTest.name]
      end

      def test_get_constantizes
        assert @cache.empty?
        assert_equal ClassCacheTest, @cache[ClassCacheTest.name]
      end

      def test_get_is_an_alias
        assert_equal @cache[ClassCacheTest], @cache.get(ClassCacheTest.name)
      end

      def test_new_rejects_strings
        @cache.store ClassCacheTest.name
        assert !@cache.key?(ClassCacheTest.name)
      end

      def test_store_returns_self
        x = @cache.store ClassCacheTest
        assert_equal @cache, x
      end
    end
  end
end
