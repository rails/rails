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

        def indexes
          @builder.indexes
        end
      end

      attr_reader :types, :default_attributes, :default_keys, :indexes

      # +default_keys+ limits which of +default_attributes+ records loaded from
      # the database fall back to (anything responding to <tt>include?</tt>).
      def initialize(types, default_attributes, default_keys)
        @types = types
        @default_attributes = default_attributes
        @default_keys = default_keys
        # Rows loaded from the database are laid out with these, so a row has
        # an index for every attribute of the model: the columns first, then
        # the other attributes, then any typed names the defaults lack.
        @indexes = indexes_for(types, default_attributes.indexes)
        @empty_row = IndexedRow.new(@indexes, [].freeze).freeze
        @init_context = InitializeContext.new(self)
      end

      # +values+ is an IndexedRow of raw values from the database. Use
      # #row_from_hash to build one from a Hash.
      def build_from_database(values, additional_types)
        LazyAttributeSet.new(values, additional_types, self)
      end

      # Lays +hash+ out like a row loaded from the database: each name at
      # its index in #indexes, and names it doesn't have after the last one.
      def row_from_hash(hash)
        row = IndexedRow::Mutable.new(@indexes)
        hash.each { |name, value| row[name] = value }
        row.freeze
      end

      # Returns +row+ if it's laid out with #indexes (possibly with extra
      # names, such as aliases, after them). Otherwise copies it into that
      # layout, as when a row laid out for an STI parent is loaded as a
      # subclass that declares attributes of its own.
      def relayout(row)
        layout = row.indexes
        layout = layout.indexes if layout.is_a?(IndexedRow::ExtendedIndexes)
        return row if layout.equal?(@indexes)

        new_row = IndexedRow::Mutable.new(@indexes)
        row.indexes.each_key { |name| new_row[name] = row.fetch(name) if row.key?(name) }
        new_row.freeze
      end

      EMPTY = {}.freeze

      def build_from_initialize(columns_hash, default_attributes)
        LazyAttributeSet.new(@empty_row, EMPTY, @init_context)
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

      private
        def indexes_for(types, indexes)
          missing = types.each_key.reject { |name| indexes.key?(name) }
          return indexes if missing.empty?

          last_ord = IndexedRow.max_ord(indexes)
          IndexedRow::ExtendedIndexes.new(indexes, missing.index_with { last_ord += 1 }.freeze)
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
