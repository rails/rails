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

      def test_new
        assert_deprecated do
          @cache.new ClassCacheTest
        end
        assert @cache.key?(ClassCacheTest.name)
      end

      def test_new_rejects_strings_when_called_on_a_new_string
        assert_deprecated do
          @cache.new ClassCacheTest.name
        end
        assert !@cache.key?(ClassCacheTest.name)
      end

      def test_new_rejects_strings
        @cache.store ClassCacheTest.name
        assert !@cache.key?(ClassCacheTest.name)
      end

      def test_store_returns_self
        x = @cache.store ClassCacheTest
        assert_equal @cache, x
      end

      def test_new_returns_proxy
        v = nil
        assert_deprecated do
          v = @cache.new ClassCacheTest.name
        end

        assert_deprecated do
          assert_equal ClassCacheTest, v.get
        end
      end

      def test_anonymous_class_fail
        assert_raises(ArgumentError) do
          assert_deprecated do
            @cache.new Class.new
          end
        end

        assert_raises(ArgumentError) do
          x = Class.new
          @cache[x] = x
        end

        assert_raises(ArgumentError) do
          x = Class.new
          @cache.store x
        end
      end
    end
  end
end
