# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"

class CacheKeyTest < ActiveSupport::TestCase
  def test_entry_legacy_optional_ivars
    legacy = Class.new(ActiveSupport::Cache::Entry) do
      def initialize(value, options = {})
        @value = value
        @expires_in = nil
        @created_at = nil
        super
      end
    end

    entry = legacy.new "foo"
    assert_equal "foo", entry.value
  end

  def test_expand_cache_key
    assert_equal "1/2/true", ActiveSupport::Cache.expand_cache_key([1, "2", true])
    assert_equal "name/1/2/true", ActiveSupport::Cache.expand_cache_key([1, "2", true], :name)
  end

  def test_expand_cache_key_with_rails_cache_id
    with_env("RAILS_CACHE_ID" => "c99") do
      assert_equal "c99/foo", ActiveSupport::Cache.expand_cache_key(:foo)
      assert_equal "c99/foo", ActiveSupport::Cache.expand_cache_key([:foo])
      assert_equal "c99/foo/bar", ActiveSupport::Cache.expand_cache_key([:foo, :bar])
      assert_equal "nm/c99/foo", ActiveSupport::Cache.expand_cache_key(:foo, :nm)
      assert_equal "nm/c99/foo", ActiveSupport::Cache.expand_cache_key([:foo], :nm)
      assert_equal "nm/c99/foo/bar", ActiveSupport::Cache.expand_cache_key([:foo, :bar], :nm)
    end
  end

  def test_expand_cache_key_with_rails_app_version
    with_env("RAILS_APP_VERSION" => "rails3") do
      assert_equal "rails3/foo", ActiveSupport::Cache.expand_cache_key(:foo)
    end
  end

  def test_expand_cache_key_rails_cache_id_should_win_over_rails_app_version
    with_env("RAILS_CACHE_ID" => "c99", "RAILS_APP_VERSION" => "rails3") do
      assert_equal "c99/foo", ActiveSupport::Cache.expand_cache_key(:foo)
    end
  end

  def test_expand_cache_key_respond_to_cache_key
    key = "foo".dup
    def key.cache_key
      :foo_key
    end
    assert_equal "foo_key", ActiveSupport::Cache.expand_cache_key(key)
  end

  def test_expand_cache_key_array_with_something_that_responds_to_cache_key
    key = "foo".dup
    def key.cache_key
      :foo_key
    end
    assert_equal "foo_key", ActiveSupport::Cache.expand_cache_key([key])
  end

  def test_expand_cache_key_of_nil
    assert_equal "", ActiveSupport::Cache.expand_cache_key(nil)
  end

  def test_expand_cache_key_of_false
    assert_equal "false", ActiveSupport::Cache.expand_cache_key(false)
  end

  def test_expand_cache_key_of_true
    assert_equal "true", ActiveSupport::Cache.expand_cache_key(true)
  end

  def test_expand_cache_key_of_array_like_object
    assert_equal "foo/bar/baz", ActiveSupport::Cache.expand_cache_key(%w{foo bar baz}.to_enum)
  end

  private

    def with_env(kv)
      old_values = {}
      kv.each { |key, value| old_values[key], ENV[key] = ENV[key], value }
      yield
    ensure
      old_values.each { |key, value| ENV[key] = value }
    end
end
