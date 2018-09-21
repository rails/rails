# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"

class KeyTest < ActiveSupport::TestCase
  def test_composability
    k1 = ActiveSupport::Cache::Key.new("foo")
    k2 = ActiveSupport::Cache::Key.new(k1)
    assert_equal k1.cache_key, k2.cache_key
  end

  def test_composable_elements
    k1 = ActiveSupport::Cache::Key.new("foo")
    k1 << "bar"
    assert_equal "foo/bar", k1.cache_key

    k2 = ActiveSupport::Cache::Key.new(["foo", "bar"])
    assert_equal k1.cache_key, k2.cache_key

    k3 = ActiveSupport::Cache::Key.new(["foo", ["bar"]])
    assert_equal k2.cache_key, k3.cache_key
  end

  def test_cache_types
    key = ActiveSupport::Cache::Key.new("foo")
    assert_equal "foo", key.cache_key

    key = ActiveSupport::Cache::Key.new(["foo", "bar"])
    assert_equal "foo/bar", key.cache_key

    key = ActiveSupport::Cache::Key.new(bar: 1, foo: 2)
    assert_equal "bar=1/foo=2", key.cache_key

    klass = Class.new { def cache_key; "foo"; end }
    key = ActiveSupport::Cache::Key.new(klass.new)
    assert_equal "foo", key.cache_key
  end

  def test_cache_version
    klass = Class.new { def cache_version; "foo"; end }
    key = ActiveSupport::Cache::Key.new(klass.new)
    assert_equal "foo", key.cache_version

    klass = Class.new { def cache_version; "foo"; end }
    key = ActiveSupport::Cache::Key.new([klass.new])
    assert_equal "foo", key.cache_version

    klass = Class.new { def cache_version; "foo"; end }
    key = ActiveSupport::Cache::Key.new(foo: klass.new)
    assert_equal "foo", key.cache_version

    key = ActiveSupport::Cache::Key.new([klass.new, klass.new])
    assert_equal "foo/foo", key.cache_version

    klass = Class.new { def cache_version; nil; end }
    key = ActiveSupport::Cache::Key.new(klass.new)
    assert_equal "", key.cache_version

    key = ActiveSupport::Cache::Key.new([klass.new, klass.new])
    assert_equal "", key.cache_version
  end

  def test_cache_version_composability
    klass = Class.new { def cache_version; "foo"; end }
    k1 = ActiveSupport::Cache::Key.new(klass.new)
    k2 = ActiveSupport::Cache::Key.new(k1)
    assert_equal k1.cache_version, k2.cache_version
  end

  def test_nil_and_empty_keys
    key = ActiveSupport::Cache::Key.new([ :a, nil, :b, "", :c ])
    assert_equal "a//b//c", key.cache_key

    key = ActiveSupport::Cache::Key.new(hello: nil, world: "today", nil: "rules")
    assert_equal "hello=/nil=rules/world=today", key.cache_key

    key = ActiveSupport::Cache::Key.new(["", "", ""])
    assert_equal "//", key.cache_key

    key = ActiveSupport::Cache::Key.new([ :foo, [], [], :bar ])
    assert_equal "foo/bar", key.cache_key
  end

  def test_nested_to_a_cache_versions
    klass = Class.new { def cache_version; "foo"; end }
    key = ActiveSupport::Cache::Key.new(hello: { world: klass.new })
    assert_equal "foo", key.cache_version
  end

  def test_call_returns_original_if_key
    k1 = ActiveSupport::Cache::Key.new("foo")
    k2 = ActiveSupport::Cache::Key(k1)
    assert_equal k1, k2

    key = ActiveSupport::Cache::Key("foo")
    assert_equal ActiveSupport::Cache::Key, key.class
    assert_equal "foo", key.cache_key
  end

  def test_enum
    k1 = ActiveSupport::Cache::Key.new([1, 2, 3].to_enum)
    assert_equal "1/2/3", k1.cache_key
  end
end
