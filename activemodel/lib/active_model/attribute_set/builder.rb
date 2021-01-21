# frozen_string_literal: true

require "active_model/attribute"

module ActiveModel
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      attr_reader :types, :default_attributes

      def initialize(types, default_attributes = {})
        @types = types
        @default_attributes = default_attributes
      end

      def build_from_database(values = {}, additional_types = {})
        LazyAttributeSet.new(values, types, additional_types, default_attributes)
      end
    end
  end

  class LazyAttributeSet < AttributeSet # :nodoc:
    def initialize(values, types, additional_types, default_attributes, attributes = {})
      super(attributes)
      @values = values
      @types = types
      @additional_types = additional_types
      @default_attributes = default_attributes
      @casted_values = {}
      @materialized = false
    end

    def key?(name)
      (values.key?(name) || types.key?(name) || @attributes.key?(name)) && self[name].initialized?
    end

    def keys
      keys = values.keys | types.keys | @attributes.keys
      keys.keep_if { |name| self[name].initialized? }
    end

    def fetch_value(name, &block)
      if attr = @attributes[name]
        return attr.value(&block)
      end

      @casted_values.fetch(name) do
        value_present = true
        value = values.fetch(name) { value_present = false }

        if value_present
          type = additional_types.fetch(name, types[name])
          @casted_values[name] = type.deserialize(value)
        else
          attr = default_attribute(name, value_present, value)
          attr.value(&block)
        end
      end
    end

    def slice!(*keep)
      [ values, types, @attributes ].each { |v| v.slice!(*keep) }
      self
    end

    protected
      def attributes
        unless @materialized
          values.each_key { |key| self[key] }
          types.each_key { |key| self[key] }
          @materialized = true
        end
        @attributes
      end

    private
      attr_reader :values, :types, :additional_types, :default_attributes

      def default_attribute(
        name,
        value_present = true,
        value = values.fetch(name) { value_present = false }
      )
        type = additional_types.fetch(name, types[name])

        if value_present
          @attributes[name] = Attribute.from_database(name, value, type, @casted_values[name])
        elsif types.key?(name)
          if attr = default_attributes[name]
            @attributes[name] = attr.dup
          else
            @attributes[name] = Attribute.uninitialized(name, type)
          end
        else
          Attribute.null(name)
        end
      end
  end

  class LazyAttributeHash # :nodoc:
    delegate :transform_values, :each_value, :fetch, :except, to: :materialize

    def initialize(types, values, additional_types, default_attributes, delegate_hash = {})
      @types = types
      @values = values
      @additional_types = additional_types
      @materialized = false
      @delegate_hash = delegate_hash
      @default_attributes = default_attributes
    end

    def key?(key)
      delegate_hash.key?(key) || values.key?(key) || types.key?(key)
    end

    def [](key)
      delegate_hash[key] || assign_default_value(key)
    end

    def []=(key, value)
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

    def each_key(&block)
      keys = types.keys | values.keys | delegate_hash.keys
      keys.each(&block)
    end

    def ==(other)
      if other.is_a?(LazyAttributeHash)
        materialize == other.materialize
      else
        materialize == other
      end
    end

    def marshal_dump
      [@types, @values, @additional_types, @default_attributes, @delegate_hash]
    end

    def marshal_load(values)
      if values.is_a?(Hash)
        ActiveSupport::Deprecation.warn(<<~MSG)
          Marshalling load from legacy attributes format is deprecated and will be removed in Rails 6.2.
        MSG
        empty_hash = {}.freeze
        initialize(empty_hash, empty_hash, empty_hash, empty_hash, values)
        @materialized = true
      else
        initialize(*values)
      end
    end

    def slice!(*keep)
      [ delegate_hash, values, types ].each { |v| v.slice!(*keep) }
      self
    end

    protected
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
      attr_reader :types, :values, :additional_types, :delegate_hash, :default_attributes

      def assign_default_value(name)
        type = additional_types.fetch(name, types[name])
        value_present = true
        value = values.fetch(name) { value_present = false }

        if value_present
          delegate_hash[name] = Attribute.from_database(name, value, type)
        elsif types.key?(name)
          attr = default_attributes[name]
          if attr
            delegate_hash[name] = attr.dup
          else
            delegate_hash[name] = Attribute.uninitialized(name, type)
          end
        end
      end
  end
end
