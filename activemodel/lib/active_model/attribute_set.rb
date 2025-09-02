# frozen_string_literal: true

require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/deep_dup"
require "active_model/attribute_set/builder"
require "active_model/attribute_set/yaml_encoder"

module ActiveModel
  class ReadOnlyAttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, to: :attributes

    def initialize(attributes)
      @attributes = attributes
      raise ArgumentError, "all attributes should be initialized" unless all_initialized?
      @attributes.freeze
      freeze
    end

    def [](name)
      @attributes[name] || default_attribute(name)
    end

    def cast_types
      attributes.transform_values(&:type)
    end

    def keys
      attributes.keys
    end

    def key?(name)
      attributes.key?(name)
    end
    alias :include? :key?

    def values
      attributes.values
    end

    def writable
      ReadWriteAttributeSet.new(self, {})
    end

    def to_hash
      keys.index_with { |name| self[name].value }
    end

    alias :to_h :to_hash

    def map(&block)
      new_attributes = attributes.transform_values(&block)
      self.class.new(new_attributes)
    end

    def deep_dup
      self.class.new(attributes.transform_values(&:deep_dup))
    end

      attr_reader :attributes
    protected

    private

      def all_initialized?
        attributes.values.all? { |v| v.initialized? }
      end

      def default_attribute(name)
        Attribute.null(name)
      end
  end

  class AttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def read_only
      ReadOnlyAttributeSet.new(attributes)
    end

    def [](name)
      @attributes[name] || default_attribute(name)
    end

    def []=(name, value)
      @attributes[name] = value
    end

    def cast_types
      attributes.transform_values(&:type)
    end

    def values_before_type_cast
      attributes.transform_values(&:value_before_type_cast)
    end

    def values_for_database
      attributes.transform_values(&:value_for_database)
    end

    def to_hash
      keys.index_with { |name| self[name].value }
    end
    alias :to_h :to_hash

    def key?(name)
      attributes.key?(name) && self[name].initialized?
    end
    alias :include? :key?

    def keys
      attributes.each_key.select { |name| self[name].initialized? }
    end

    def fetch_value(name, &block)
      self[name].value(&block)
    end

    def write_from_database(name, value)
      @attributes[name] = self[name].with_value_from_database(value)
    end

    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      @attributes[name] = self[name].with_value_from_user(value)
      value
    end

    def write_cast_value(name, value)
      @attributes[name] = self[name].with_cast_value(value)
    end

    def freeze
      attributes.freeze
      super
    end

    def deep_dup
      AttributeSet.new(attributes.transform_values(&:dup_or_share))
    end

    def initialize_dup(_)
      @attributes = @attributes.dup
      super
    end

    def initialize_clone(_)
      @attributes = @attributes.clone
      super
    end

    def reset(key)
      if key?(key)
        write_from_database(key, nil)
      end
    end

    def accessed
      attributes.each_key.select { |name| self[name].has_been_read? }
    end

    def map(&block)
      new_attributes = attributes.transform_values(&block)
      AttributeSet.new(new_attributes)
    end

    def values
      attributes.values
    end

    def reverse_merge!(target_attributes)
      attributes.reverse_merge!(target_attributes.attributes) && self
    end

    def ==(other)
      other.class == self.class && attributes == other.attributes
    end

    protected
      attr_reader :attributes

    private
      def default_attribute(name)
        Attribute.null(name)
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

    def deep_dup
      LazyAttributeSet.new(
        values.dup,
        types.dup,
        additional_types.dup,
        default_attributes.dup,
        attributes.transform_values(&:deep_dup)
      )
    end

    def map(&block)
      LazyAttributeSet.new(
        values,
        types,
        additional_types,
        default_attributes,
        attributes.transform_values(&block)
      )
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
end
