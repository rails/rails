# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"


module ActiveSupport
  module Cache
    class KeyTest < ActiveSupport::TestCase
      def test_composability
        k1 = Key.new("foo")
        k2 = Key.new(k1)
        assert_equal k1.cache_key, k2.cache_key
      end

      def test_composable_elements
        k1 = Key.new("foo")
        k1 << "bar"
        assert_equal "foo/bar", k1.cache_key

        k2 = Key.new(["foo", "bar"])
        assert_equal k1.cache_key, k2.cache_key

        k3 = Key.new(["foo", ["bar"]])
        assert_equal k2.cache_key, k3.cache_key
      end

      def test_cache_types
        key = Key.new("foo")
        assert_equal "foo", key.cache_key

        key = Key.new(["foo", "bar"])
        assert_equal "foo/bar", key.cache_key

        key = Key.new(bar: 1, foo: 2)
        assert_equal "bar=1/foo=2", key.cache_key

        klass = Class.new { def cache_key; "foo"; end }
        key = Key.new(klass.new)
        assert_equal "foo", key.cache_key
      end

      def test_cache_version
        klass = Class.new { def cache_version; "foo"; end }
        key = Key.new(klass.new)
        assert_equal "foo", key.cache_version

        klass = Class.new { def cache_version; "foo"; end }
        key = Key.new([klass.new])
        assert_equal "foo", key.cache_version

        klass = Class.new { def cache_version; "foo"; end }
        key = Key.new(foo: klass.new)
        assert_equal "foo", key.cache_version

        key = Key.new([klass.new, klass.new])
        assert_equal "foo/foo", key.cache_version

        klass = Class.new { def cache_version; nil; end }
        key = Key.new(klass.new)
        assert_equal "", key.cache_version

        key = Key.new([klass.new, klass.new])
        assert_equal "", key.cache_version
      end

      def test_cache_version_composability
        klass = Class.new { def cache_version; "foo"; end }
        k1 = Key.new(klass.new)
        k2 = Key.new(k1)
        assert_equal k1.cache_version, k2.cache_version
      end

      def test_nil_and_empty_keys
        key = Key.new([ :a, nil, :b, "", :c ])
        assert_equal "a//b//c", key.cache_key

        key = Key.new(hello: nil, world: "today", nil: "rules")
        assert_equal "hello=/nil=rules/world=today", key.cache_key

        key = Key.new(["", "", ""])
        assert_equal "//", key.cache_key

        key = Key.new([ :foo, [], [], :bar ])
        assert_equal "foo///bar", key.cache_key
      end

      def test_nested_to_a_cache_versions
        klass = Class.new { def cache_version; "foo"; end }
        key = Key.new(hello: { world: klass.new })
        assert_equal "foo", key.cache_version
      end

      def test_call_returns_original_if_key
        k1 = Key.new("foo")
        k2 = Key.new(k1)
        assert_equal k1.cache_key, k2.cache_key

        key = Key.new("foo")
        assert_equal Key, key.class
        assert_equal "foo", key.cache_key
      end
    end
  end
end