# frozen_string_literal: true

require "abstract_unit"
require "active_support/dependencies"

module ActiveSupport
  module Dependencies
    class ClassCacheTest < ActiveSupport::TestCase
      def setup
        @cache = ClassCache.new
      end

      def test_empty?
        assert_empty @cache
        @cache.store(ClassCacheTest)
        assert_not_empty @cache
      end

      def test_clear!
        assert_empty @cache
        @cache.store(ClassCacheTest)
        assert_not_empty @cache
        @cache.clear!
        assert_empty @cache
      end

      def test_set_key
        @cache.store(ClassCacheTest)
        assert @cache.key?(ClassCacheTest.name)
      end

      def test_get_with_class
        @cache.store(ClassCacheTest)
        assert_equal ClassCacheTest, @cache.get(ClassCacheTest)
      end

      def test_get_with_name
        @cache.store(ClassCacheTest)
        assert_equal ClassCacheTest, @cache.get(ClassCacheTest.name)
      end

      def test_get_constantizes
        assert_empty @cache
        assert_equal ClassCacheTest, @cache.get(ClassCacheTest.name)
      end

      def test_get_constantizes_fails_on_invalid_names
        assert_empty @cache
        assert_raise NameError do
          @cache.get("OmgTotallyInvalidConstantName")
        end
      end

      def test_get_alias
        assert_empty @cache
        assert_equal @cache[ClassCacheTest.name], @cache.get(ClassCacheTest.name)
      end

      def test_safe_get_constantizes
        assert_empty @cache
        assert_equal ClassCacheTest, @cache.safe_get(ClassCacheTest.name)
      end

      def test_safe_get_constantizes_doesnt_fail_on_invalid_names
        assert_empty @cache
        assert_nil @cache.safe_get("OmgTotallyInvalidConstantName")
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
