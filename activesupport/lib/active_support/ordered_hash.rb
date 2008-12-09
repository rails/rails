# OrderedHash is namespaced to prevent conflicts with other implementations
module ActiveSupport
  # Hash is ordered in Ruby 1.9!
  if RUBY_VERSION >= '1.9'
    OrderedHash = ::Hash
  else
    class OrderedHash < Hash #:nodoc:
      def initialize(*args, &block)
        super
        @keys = []
      end

      def []=(key, value)
        if !has_key?(key)
          @keys << key
        end
        super
      end

      def delete(key)
        array_index = has_key?(key) && index(key)
        if array_index
          @keys.delete_at(array_index)
        end
        super
      end

      def keys
        @keys
      end

      def values
        @keys.collect { |key| self[key] }
      end

      def to_hash
        Hash.new(self)
      end

      def each_key
        @keys.each { |key| yield key }
      end

      def each_value
        @keys.each { |key| yield self[key]}
      end

      def each
        keys.each {|key| yield [key, self[key]]}
      end
    end
  end
end
