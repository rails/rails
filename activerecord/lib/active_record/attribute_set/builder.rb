module ActiveRecord
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      attr_reader :types, :always_initialized

      def initialize(types, always_initialized = nil)
        @types = types
        @always_initialized = always_initialized
      end

      def build_from_database(values = {}, additional_types = {})
        if always_initialized && !values.key?(always_initialized)
          values[always_initialized] = nil
        end

        attributes = LazyAttributeHash.new(types, values, additional_types)
        AttributeSet.new(attributes)
      end
    end
  end

  class LazyAttributeHash
    delegate :select, :transform_values, to: :materialize

    def initialize(types, values, additional_types)
      @types = types
      @values = values
      @additional_types = additional_types
      @materialized = false
      @delegate_hash = {}
    end

    def key?(key)
      delegate_hash.key?(key) || values.key?(key) || types.key?(key)
    end

    def [](key)
      delegate_hash.fetch(key) do
        assign_default_value(key)
      end
    end

    def []=(key, value)
      if frozen?
        raise RuntimeError, "Can't modify frozen hash"
      end
      delegate_hash[key] = value
    end

    def initialized_keys
      delegate_hash.keys | values.keys
    end

    def initialize_dup(_)
      @delegate_hash = delegate_hash.transform_values(&:dup)
      super
    end

    protected

    attr_reader :types, :values, :additional_types, :delegate_hash

    private

    def assign_default_value(name)
      type = additional_types.fetch(name, types[name])
      converted = false

      val = values.fetch(name) do
        converted = true

        if types.key?(name)
          val = Attribute.uninitialized(name, type)
          delegate_hash[name] = val
        end
      end

      unless converted
        val = Attribute.from_database(name, val, type)
        delegate_hash[name] = val
      end

      val
    end

    def materialize
      unless @materialized
        values.each_key { |key| self[key] }
        types.each_key { |key| self[key] }
        @materialized = true
      end
      delegate_hash
    end
  end
end
