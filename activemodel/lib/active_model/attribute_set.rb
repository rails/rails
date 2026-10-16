# frozen_string_literal: true

# :markup: markdown
require "active_support/core_ext/enumerable"
require "active_support/core_ext/object/deep_dup"
require "active_model/attribute_set/builder"
require "active_model/attribute_set/yaml_encoder"

module ActiveModel
  # +attributes+ is an IndexedRow of Attribute objects.
  class ReadOnlyAttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, :indexes, to: :attributes

    def initialize(attributes)
      @attributes = attributes
      raise ArgumentError, "all attributes should be initialized" unless all_initialized?
      freeze
    end

    def [](name)
      @attributes[name] || default_attribute(name)
    end

    def cast_types
      attributes.to_h.transform_values(&:type)
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
      AttributeSet.new(attributes.transform_values(&:dup))
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

    def ==(other)
      other.class == self.class && attributes == other.attributes
    end

    def read_only?
      true
    end

    attr_reader :attributes

    private
      def all_initialized?
        attributes.values.all? { |v| v.initialized? }
      end

      def default_attribute(name)
        Attribute.null(name)
      end
  end

  # +attributes+ is an IndexedRow::Mutable of Attribute objects.
  class AttributeSet # :nodoc:
    delegate :each_value, :fetch, :except, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def indexes
      attributes.indexes
    end

    def read_only
      attributes.values.each(&:freeze)
      attributes.freeze
      ReadOnlyAttributeSet.new(attributes)
    end

    def [](name)
      lookup(name) || default_attribute(name)
    end

    def []=(name, value)
      store(name, value)
    end

    def cast_types
      attributes.to_h.transform_values(&:type)
    end

    def values_before_type_cast
      attributes.to_h.transform_values(&:value_before_type_cast)
    end

    def values_for_database
      attributes.to_h.transform_values(&:value_for_database)
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

    # Like #fetch_value, but raises MissingAttributeError if the attribute is
    # uninitialized.
    def fetch_value!(name)
      self[name].value!
    end

    def write_from_database(name, value)
      store(name, self[name].with_value_from_database(value))
    end

    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      store(name, self[name].with_value_from_user(value))
      value
    end

    def write_cast_value(name, value)
      store(name, self[name].with_cast_value(value))
    end

    def freeze
      freeze_attributes
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
      own = attributes
      target = target_attributes.attributes
      target.each_key do |name|
        store(name, target[name]) unless own.key?(name)
      end
      self
    end

    def ==(other)
      other.class == self.class && attributes == other.attributes
    end

    def read_only?
      false
    end

    protected
      attr_reader :attributes

    private
      def lookup(name)
        @attributes[name]
      end

      def store(name, attribute)
        @attributes[name] = attribute
      end

      def freeze_attributes
        attributes.freeze
      end

      def default_attribute(name)
        Attribute.null(name)
      end
  end

  # Attributes are cached in a plain Array, by the index of the attribute's
  # name in +indexes+ (initially the indexes of +default_attributes+). Names
  # that aren't in +indexes+ are added after the last index.
  class LazyAttributeSet < AttributeSet # :nodoc:
    def indexes
      @indexes || upgrade_legacy_ivars
    end

    def initialize(values, additional_types, ctx)
      super([])
      # The raw data from the database
      @values = values

      # Additional types (like from `select count(*) as blah`)
      @additional_types = additional_types
      @ctx = ctx
      @casted_values = values.is_a?(IndexedRow) ? values.new_empty_mutable_row : {}
      @materialized = false
      @indexes = default_attributes.indexes
    end

    def initialize_copy(other)
      super
      @casted_values = @casted_values.dup
    end

    def key?(name)
      values.key?(name) || ((@ctx.type_key?(name) || !lookup(name).nil?) && self[name].initialized?)
    end

    def keys
      keys = values.keys | @ctx.type_keys | cached_names
      keys.keep_if { |name| self[name].initialized? }
    end

    def fetch_value(name, &block)
      if attr = lookup(name)
        return attr.value(&block)
      end

      @casted_values.fetch(name) do
        value_present = true
        value = values.fetch(name) { value_present = false }

        if value_present
          type = additional_types.fetch(name, @ctx.type_for_name(name))
          @casted_values[name] = type.deserialize(value)
        else
          attr = default_attribute(name, value_present, value)
          attr.value(&block)
        end
      end
    end

    def fetch_value!(name)
      if attr = lookup(name)
        return attr.value!
      end

      @casted_values.fetch(name) do
        value_present = true
        value = values.fetch(name) { value_present = false }

        if value_present
          type = additional_types.fetch(name, @ctx.type_for_name(name))
          @casted_values[name] = type.deserialize(value)
        else
          default_attribute(name, value_present, value).value!
        end
      end
    end

    def deep_dup
      map(&:deep_dup)
    end

    def map(&block)
      materialize
      dup.transform_attributes!(&block)
    end

    protected
      # An IndexedRow of every attribute, for the methods that work on all
      # of them. Built on each call, so writes must go through #store.
      def attributes
        materialize

        row = IndexedRow.unset_row(@attributes.size)
        @attributes.each_with_index { |attr, i| row[i] = attr if attr }
        IndexedRow::Mutable.new(indexes, row)
      end

      # Replaces each cached attribute with the block's result. Only for
      # fresh copies, since it modifies +@attributes+ in place.
      def transform_attributes!
        @attributes.map! { |attr| attr && yield(attr) }
        self
      end

    private
      attr_reader :values, :types, :additional_types

      def default_attributes
        @ctx.default_attributes
      end

      def materialize
        unless @materialized
          values.each_key { |key| self[key] }
          @ctx.type_keys.each { |key| self[key] }
          @materialized = true
        end
      end

      def lookup(name)
        if entry = (@indexes || upgrade_legacy_ivars)[name]
          @attributes[entry.ord]
        end
      end

      def store(name, attribute)
        if entry = (@indexes || upgrade_legacy_ivars)[name]
          index = entry.ord
        else
          index = [@attributes.size, IndexedRow.max_ord(@indexes) + 1].max
          @indexes = IndexedRow::ExtendedIndexes.add(@indexes, name, index)
        end

        @attributes[index] = attribute
      end

      def cached_names
        indexes.each_key.select { |name| lookup(name) }
      end

      # Sets loaded from older Marshal dumps (e.g. Rails 6.1) have their
      # instance variables restored directly, with +@attributes+ as a Hash
      # and no +@indexes+. Convert them to the Array layout on first use.
      def upgrade_legacy_ivars
        legacy = @attributes
        @indexes = IndexedRow.build_indexes(legacy.keys).freeze
        @attributes = legacy.values
        @indexes
      end

      def freeze_attributes
        materialize
        @attributes.freeze
      end

      def default_attribute(
        name,
        value_present = true,
        value = values.fetch(name) { value_present = false }
      )
        type = additional_types.fetch(name, @ctx.type_for_name(name))

        if value_present
          store(name, Attribute.from_database(name, value, type, @casted_values[name]))
        elsif @ctx.type_key?(name)
          if @ctx.needs_default?(name) && (attr = default_attributes.fetch(name) { nil })
            store(name, attr.dup)
          else
            store(name, Attribute.uninitialized(name, type))
          end
        else
          Attribute.null(name)
        end
      end
  end
end
