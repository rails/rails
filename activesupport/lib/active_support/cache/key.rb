# frozen_string_literal: true

module ActiveSupport
  module Cache
    # Convenience method to prevent re-generating a Key
    # instance, if the element being passed in is already
    # instance of the `Key` class.
    #
    # Example:
    #
    #   ActiveSupport::Cache::Key("foo").cache_key
    #    # => "foo"
    #
    #   k1 = Key.new("foo")
    #   key = ActiveSupport::Cache::Key(k1)
    #   k1.object_id == key.object_id # => true
    def self.Key(key_or_components) # :nodoc:
      if key_or_components.is_a?(ActiveSupport::Cache::Key)
        key_or_components
      else
        Key.new(key_or_components)
      end
    end

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
      attr_reader :cache_key, :cache_version

      def initialize(key = nil)
        @cache_key = +""
        @cache_version = +""
        @empty_key = true
        @key_parts = []
        self << key
      end

      def length
        @cache_key.length
      end

      def self.cache_key_with_version(key)
        case
        when key.respond_to?(:cache_key_with_version) then key.cache_key_with_version
        when key.respond_to?(:cache_key)              then key.cache_key
        when key.is_a?(Array)                         then key.map { |element| cache_key_with_version(element) }.to_param
        when key.respond_to?(:to_a)                   then cache_key_with_version(key.to_a)
        else                                               key.to_param
        end.to_s
      end

      def cache_key_with_version(key = @key_parts)
        self.class.cache_key_with_version(key)
      end

      def update(key)
        @key_parts << key
        internal_update(key)
        self
      end
      alias :<< :update

      private
        def internal_update(key)
          if key.respond_to?(:cache_key)
            update_version(key)
            update_key(key.cache_key.to_s)
          else
            split_key(key)
          end
        end

        def update_key(key)
          @cache_key << "/" unless @empty_key
          @cache_key << key.to_param.to_s
          @empty_key = false
        end

        def update_version(key)
          if key.respond_to?(:cache_version)
            @cache_version << "/" unless @cache_version.empty?
            @cache_version << key.cache_version.to_param.to_s
          else
            split_version(key)
          end
        end

        def split_key(key)
          case key
          when Array
            key.each { |k| internal_update(k) }
          when Hash
            key = key.to_a
            update_version(key)
            key.sort_by! { |k, _| k.to_s }
            key.each { |k, v| update_key("#{k}=#{v}") }
          else
            if key.respond_to?(:to_a) && !key.nil?
              internal_update(key.to_a)
            else
              update_version(key)
              update_key(key)
            end
          end
        end

        def split_version(key)
          if key.is_a?(Array)
            key.each { |k| update_version(k) }
          elsif key.respond_to?(:to_a)
            split_version(key.to_a)
          end
        end
    end
  end
end
