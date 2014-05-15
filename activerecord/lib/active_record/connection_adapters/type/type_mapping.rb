module ActiveRecord::ConnectionAdapters::Type
  class TypeMapping
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
      raise ArgumentError unless value || block

      if block
        @mapping[key] = block
      else
        @mapping[key] = proc { value }
      end
    end

    def alias_type(key, target_key)
      @mapping[key] = proc { lookup(target_key) }
    end

    def clear
      @mapping.clear
    end
  end
end
