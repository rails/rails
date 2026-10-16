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

    def initialize_clone(...)
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
  # name in the indexes of +values+, which cover every attribute of the
  # model plus any extra columns (such as aliases) the row was loaded with.
  # Methods that take a name look its index up once and work by index from
  # there.
  class LazyAttributeSet < AttributeSet # :nodoc:
    # Marks the slots in +@casted_values+ that haven't been cast yet, since
    # a value can be cast to +nil+.
    UNCAST = Object.new.freeze
    private_constant :UNCAST

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
      # Values cast from +values+, by the same index. Only values in the
      # row are cast, so this is never longer than the row.
      @casted_values = [UNCAST] * values.row.size
      @materialized = false
      @indexes = values.indexes
    end

    def initialize_copy(other)
      super
      @casted_values = @casted_values.dup
    end

    def [](name)
      if index = index_for_name(name)
        attribute_at(name, index)
      else
        Attribute.null(name)
      end
    end

    def []=(name, attribute)
      store(indexes.fetch(name).ord, attribute)
    end

    def key?(name)
      index = index_for_name(name)
      return false unless index

      values.key_at?(index) ||
        ((@ctx.type_key?(name) || !lookup(index).nil?) && attribute_at(name, index).initialized?)
    end

    def keys
      keys = values.keys | @ctx.type_keys | cached_names
      keys.keep_if { |name| self[name].initialized? }
    end

    def fetch_value(name, &block)
      index = index_for_name(name)
      return unless index

      if attr = lookup(index)
        attr.value(&block)
      else
        fetch_cast_value(name, index) { |attribute| attribute.value(&block) }
      end
    end

    def fetch_value!(name)
      index = index_for_name(name)
      return unless index

      if attr = lookup(index)
        attr.value!
      else
        fetch_cast_value(name, index, &:value!)
      end
    end

    def write_from_database(name, value)
      write(name) { |attribute| attribute.with_value_from_database(value) }
    end

    def write_from_user(name, value)
      raise FrozenError, "can't modify frozen attributes" if frozen?
      write(name) { |attribute| attribute.with_value_from_user(value) }
      value
    end

    def write_cast_value(name, value)
      write(name) { |attribute| attribute.with_cast_value(value) }
    end

    def deep_dup
      map(&:deep_dup)
    end

    def map(&block)
      materialize
      dup.transform_attributes!(&block)
    end

    # Used by +becomes+, where the record takes on the attributes of another
    # class. This is the only way a set gains names its row doesn't have, so
    # their indexes are added after the last one here.
    def reverse_merge!(target_attributes)
      own = attributes
      target = target_attributes.attributes
      target.each_key do |name|
        next if own.key?(name)

        unless index = index_for_name(name)
          index = [@attributes.size, IndexedRow.max_ord(@indexes) + 1].max
          @indexes = IndexedRow::ExtendedIndexes.add(@indexes, name, index)
        end
        store(index, target[name])
      end
      self
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
      attr_reader :values, :additional_types

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

      # +indexes+ has every name the set can hold, so a name without an
      # index isn't an attribute.
      def index_for_name(name)
        indexes[name]&.ord
      end

      def lookup(index)
        @attributes[index]
      end

      def store(index, attribute)
        @attributes[index] = attribute
      end

      def attribute_at(name, index)
        lookup(index) || default_attribute(name, index)
      end

      # Stores the block's result for the attribute +name+. Unknown names
      # get Attribute::Null, which raises before anything is stored.
      def write(name)
        index = index_for_name(name)
        attribute = index ? attribute_at(name, index) : Attribute.null(name)
        store(index, yield(attribute))
      end

      # The value at +index+ for an attribute that hasn't been built yet:
      # cast from the row (and kept in +@casted_values+), or the block's
      # result for the default attribute when the row doesn't have it.
      def fetch_cast_value(name, index)
        value = @casted_values.fetch(index, UNCAST)
        return value unless UNCAST.equal?(value)

        value_present = true
        value = values.fetch_at(index) { value_present = false }

        if value_present
          @casted_values[index] = type_for(name).deserialize(value)
        else
          yield default_attribute(name, index, false, nil)
        end
      end

      def type_for(name)
        additional_types.fetch(name, @ctx.type_for_name(name))
      end

      def cached_names
        indexes.each_key.select { |name| lookup(index_for_name(name)) }
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
        index,
        value_present = true,
        value = values.fetch_at(index) { value_present = false }
      )
        if value_present
          casted = @casted_values.fetch(index, UNCAST)
          casted = nil if UNCAST.equal?(casted)
          store(index, Attribute.from_database(name, value, type_for(name), casted))
        elsif @ctx.type_key?(name)
          if @ctx.needs_default?(name) && (attr = default_attributes.fetch(name) { nil })
            store(index, attr.dup)
          else
            store(index, Attribute.uninitialized(name, type_for(name)))
          end
        else
          Attribute.null(name)
        end
      end
  end
end
