module ActiveRecord
  module ConnectionAdapters
    module Type
      class TypeMap
        def initialize
          @mapping = {}
          @default_value = Value.new
        end

        def lookup(lookup_key)
          matching_pair = @mapping.reverse_each.detect do |key, _|
            key === lookup_key
          end

          if matching_pair
            matching_pair.last.call(lookup_key)
          else
            @default_value
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
          register_type(key) { lookup(target_key) }
        end

        def alias_type_with_meta(key, target_key)
          register_type(key) do |sql_type|
            metadata = sql_type[/\(.*\)/, 0]
            lookup("#{target_key}#{metadata}")
          end
        end

        def clear
          @mapping.clear
        end
      end
    end
  end
end
