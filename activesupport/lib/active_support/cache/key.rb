# frozen_string_literal: true

require "active_support/cache"

module ActiveSupport
  module Cache
    # This class is responsible for coercing input into a valid
    # key format and cache version for cache stores.
    #
    # The goal of this class is to provide a composable way
    # to build keys. You can put an instance of Key
    # into another instance of Key and it should produce
    # the same `cache_key` and `cache_version`.
    #
    # Example:
    #
    #   k1 = Key.new("foo")
    #   k2 = Key.new(k1)
    #   k1.cache_key == k2.cache_key
    #   # => true
    #
    # In addition to passing a key into the initialize method,
    # key fragments can be added onto an existing key through the
    # `<<` method.
    #
    # Example:
    #
    #   key = Key.new
    #   key << "foo"
    #   key << "bar"
    #   key.cache_key
    #   # => "foo/bar"
    #
    # Multiple key entries generate the same key regardless of how
    # they are added. I.e. if they're added via multiple arrays
    # or directly via the `<<` operator.
    #
    # Example:
    #
    #   k1 = Key.new("foo")
    #   k1 << "bar"
    #   k2 = Key.new(["foo", "bar"])
    #   k1.cache_key == k2.cache_key
    #   # => true
    #   k3 = Key.new(["foo", ["bar"]])
    #   k2.cache_key == k3.cache_key
    #   # => true
    #
    # It is faster to directly add objects to the
    # Key object via `<<` than to generate
    # an intermediate array of objects.
    #
    # The class supports strings, arrays, hashes,
    # objects with a `cache_key` method and anything
    # that can be implicitly cast to a string:
    #
    # Examples:
    #
    #   Key.new("foo").cache_key
    #   # => "foo"
    #
    #   Key.new(["foo", "bar"]).cache_key
    #   # => "foo/bar"
    #
    #   Key.new({ bar: 1, foo: 2 }).cache_key
    #   # => "bar=1/foo=2"
    #
    #   klass = Class.new { def cache_key; "foo"; end }
    #   Key.new(klass.new).cache_key
    #   # => "foo"
    #
    # In addition to generating a `cache_key`,
    # a `cache_version` is also generated if the object
    # passed in responds to `cache_version` or if it contains
    # an element that responds to `cache_version`.
    #
    # The purpose of keeping this value seperate from
    # `cache_key` is to support the use of "cache versioning"
    # where the same key is recycled but the version of the object
    # being stored is kept directly in the cache.
    #
    # Example:
    #
    #   klass = Class.new { def cache_version; "foo"; end }
    #   Key.new(klass.new).cache_version
    #   # => "foo"
    #
    #   klass = Class.new { def cache_version; "foo"; end }
    #   Key.new([klass.new]).cache_version
    #   # => "foo"
    #
    #   klass = Class.new { def cache_version; "foo"; end }
    #   Key.new({foo: klass.new}).cache_version
    #   # => "foo"
    class Key # :nodoc:
      DEFAULT_KEY = Object.new
      CACHE_METHOD_OBJ = ActiveSupport::Cache::Store.new

      def initialize(key = DEFAULT_KEY)
        @cache_key = nil
        @cache_version = nil
        @key_parts = []
        self << key unless key == DEFAULT_KEY
      end

      def cache_key
        @cache_key ||= begin
          cache_method_obj.send(:expanded_key, @key_parts)
        end
      end

      def cache_version
        @cache_version ||= begin
          cache_method_obj.send(:expanded_version, @key_parts)
        end
      end

      def cache_key_with_version
        cache_method_obj.send(:retrieve_cache_key, @key_parts)
      end

      def update(key)
        @key_parts << key
        @cache_key = nil
        @cache_version = nil
        self
      end
      alias :<< :update

      def length
        cache_key.length
      end

      private
        def cache_method_obj
          defined?(Rails) && Rails.respond_to?(:cache) ? Rails.cache : CACHE_METHOD_OBJ
        end
    end
  end
end
