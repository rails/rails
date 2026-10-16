# frozen_string_literal: true

require "active_model/attribute"

module ActiveModel
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      class InitializeContext # :nodoc:
        def initialize(builder)
          @builder = builder
          freeze
        end

        def needs_default?(name)
          true
        end

        def type_keys
          @builder.type_keys
        end

        def type_key?(name)
          @builder.type_key?(name)
        end

        def type_for_name(name)
          @builder.type_for_name(name)
        end

        def default_attributes
          @builder.default_attributes
        end
      end

      attr_reader :types, :default_attributes, :default_keys

      # +default_keys+ limits which of +default_attributes+ records loaded from
      # the database fall back to (anything responding to <tt>include?</tt>).
      def initialize(types, default_attributes, default_keys)
        @types = types
        @default_attributes = default_attributes
        @default_keys = default_keys
        @init_context = InitializeContext.new(self)
      end

      def build_from_database(values, additional_types)
        LazyAttributeSet.new(values, additional_types, self)
      end

      EMPTY = {}.freeze

      def build_from_initialize(columns_hash, default_attributes)
        LazyAttributeSet.new(EMPTY, EMPTY, @init_context)
      end

      def needs_default?(name)
        @default_keys.include?(name)
      end

      def type_keys
        @types.keys
      end

      def type_key?(name)
        @types.key?(name)
      end

      def type_for_name(name)
        @types[name]
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
      initialize(*values)
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
