require 'active_record/attribute'

module ActiveRecord
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      attr_reader :types, :always_initialized, :default

      def initialize(types, always_initialized = nil, &default)
        @types = types
        @always_initialized = always_initialized
        @default = default
      end

      def build_from_database(values = {}, additional_types = {})
        if always_initialized && !values.key?(always_initialized)
          values[always_initialized] = nil
        end

        attributes = LazyAttributeHash.new(types, values, additional_types, &default)
        AttributeSet.new(attributes)
      end
    end
  end

  class LazyAttributeHash # :nodoc:
    delegate :transform_values, :each_key, :each_value, :fetch, to: :materialize

    def initialize(types, values, additional_types, &default)
      @types = types
      @values = values
      @additional_types = additional_types
      @materialized = false
      @delegate_hash = {}
      @default = default || proc {}
    end

    def key?(key)
      delegate_hash.key?(key) || values.key?(key) || types.key?(key)
    end

    def [](key)
      delegate_hash[key] || assign_default_value(key)
    end

    def []=(key, value)
      if frozen?
        raise RuntimeError, "Can't modify frozen hash"
      end
      delegate_hash[key] = value
    end

    def deep_dup
      dup.tap do |copy|
        copy.instance_variable_set(:@delegate_hash, delegate_hash.transform_values(&:dup))
      end
    end

    def initialize_dup(_)
      @delegate_hash = Hash[delegate_hash]
      super
    end

    def select
      keys = types.keys | values.keys | delegate_hash.keys
      keys.each_with_object({}) do |key, hash|
        attribute = self[key]
        if yield(key, attribute)
          hash[key] = attribute
        end
      end
    end

    def ==(other)
      if other.is_a?(LazyAttributeHash)
        materialize == other.materialize
      else
        materialize == other
      end
    end

    def marshal_dump
      materialize
    end

    def marshal_load(delegate_hash)
      @delegate_hash = delegate_hash
      @types = {}
      @values = {}
      @additional_types = {}
      @materialized = true
    end

    protected

    attr_reader :types, :values, :additional_types, :delegate_hash, :default

    def materialize
      unless @materialized
        values.each_key { |key| self[key] }
        types.each_key { |key| self[key] }
        unless frozen?
          @materialized = true
        end
      end
      delegate_hash
    end

    private

    def assign_default_value(name)
      type = additional_types.fetch(name, types[name])
      value_present = true
      value = values.fetch(name) { value_present = false }

      if value_present
        delegate_hash[name] = Attribute.from_database(name, value, type)
      elsif types.key?(name)
        delegate_hash[name] = default.call(name) || Attribute.uninitialized(name, type)
      end
    end
  end
end
