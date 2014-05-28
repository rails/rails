module ActiveRecord
  module Type
    class TypeMap # :nodoc:
      def initialize
        @mapping = {}
      end

      def lookup(lookup_key, *args)
        matching_pair = @mapping.reverse_each.detect do |key, _|
          key === lookup_key
        end

        if matching_pair
          matching_pair.last.call(lookup_key, *args)
        else
          default_value
        end
      end

      def register_type(key, value = nil, &block)
        raise ::ArgumentError unless value || block

        if block
          @mapping[key] = block
        else
          @mapping[key] = proc { value }
        end
      end

      def alias_type(key, target_key)
        register_type(key) do |sql_type, *args|
          metadata = sql_type[/\(.*\)/, 0]
          lookup("#{target_key}#{metadata}", *args)
        end
      end

      def clear
        @mapping.clear
      end

      private

      def default_value
        @default_value ||= Value.new
      end
    end
  end
end
