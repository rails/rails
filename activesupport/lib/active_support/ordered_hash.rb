# OrderedHash is namespaced to prevent conflicts with other implementations
module ActiveSupport
  # Hash is ordered in Ruby 1.9!
  if RUBY_VERSION >= '1.9'
    OrderedHash = ::Hash
  else
    class OrderedHash < Array #:nodoc:
      def []=(key, value)
        if pair = assoc(key)
          pair.pop
          pair << value
        else
          self << [key, value]
        end
      end

      def [](key)
        pair = assoc(key)
        pair ? pair.last : nil
      end

      def delete(key)
        pair = assoc(key)
        pair ? array_index = index(pair) : nil
        array_index ? delete_at(array_index).last : nil
      end

      def keys
        collect { |key, value| key }
      end

      def values
        collect { |key, value| value }
      end

      def to_hash
        returning({}) do |hash|
          each { |array| hash[array[0]] = array[1] }
        end
      end
    end
  end
end
