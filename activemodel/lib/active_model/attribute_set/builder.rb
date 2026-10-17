# frozen_string_literal: true

require "active_model/attribute"

module ActiveModel
  class AttributeSet # :nodoc:
    class Builder # :nodoc:
      # What a LazyAttributeSet looks up about the model's attributes, by
      # their index in the builder's #indexes.
      class Context # :nodoc:
        attr_reader :type_keys

        # +names+ are the attribute names by index, +types+ a Hash of types
        # by name, and +defaults+ the default attributes by index that
        # attributes a row doesn't have fall back to.
        def initialize(names, types, defaults)
          @names = names
          @types = names.map { |name| types[name] }.freeze
          @type_keys_lut = names.map { |name| types.key?(name) }.freeze
          @type_keys = types.keys.freeze
          @defaults = defaults
          freeze
        end

        def type_key_at?(index)
          @type_keys_lut[index]
        end

        # The type of the attribute at +index+. Indexes after the model's
        # are for names a row has that the model doesn't, typed by
        # +additional_types+ in order.
        def type_at(index, additional_types)
          if index < @types.size
            @types[index]
          else
            additional_types[index - @types.size] || Type.default_value
          end
        end

        # The name of the attribute at +index+.
        def name_at(index)
          @names[index]
        end

        # The default attribute for the attribute at +index+, if any.
        def default_at(index)
          @defaults[index]
        end
      end

      # For records loaded from the database, which only fall back to the
      # defaults in +default_keys+. Other attributes the row doesn't have
      # are missing.
      class FromDBContext < Context # :nodoc:
        def initialize(names, types, defaults, default_keys)
          defaults = names.each_with_index.map do |name, index|
            defaults[index] if default_keys.include?(name)
          end
          super(names, types, defaults.freeze)
        end
      end

      # For new records, which fall back to every default.
      class FromInitContext < Context # :nodoc:
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
        @names = names_for(@indexes)
        @defaults = @names.map { |name| default_attributes.fetch(name) { nil } }.freeze
        @from_db_context = FromDBContext.new(@names, types, @defaults, default_keys)
        @from_init_context = FromInitContext.new(@names, types, @defaults)
        @empty_row = IndexedRow.new(@indexes, [].freeze).freeze
        freeze
      end

      EMPTY_TYPES = [].freeze

      # +values+ is an IndexedRow of raw values from the database. Use
      # #row_from_hash to build one from a Hash. +additional_types+ are the
      # types of the names +values+ has after the ones in #indexes (such as
      # aliases), in order (see #type_at).
      def build_from_database(values, additional_types = EMPTY_TYPES)
        LazyAttributeSet.new(values, additional_types, @from_db_context)
      end

      def build_from_initialize
        LazyAttributeSet.new(@empty_row, EMPTY_TYPES, @from_init_context)
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

      # Copies the attributes of +attribute_set+, which may be laid out some
      # other way (as when decoded from YAML), into a set laid out with
      # #indexes, so it can be read by index.
      def relayout_attributes(attribute_set)
        attributes = IndexedRow::Mutable.new(@indexes)
        attribute_set.each_value { |attribute| attributes[attribute.name] = attribute }
        AttributeSet.new(attributes)
      end

      # A copy of this builder that uses +types+ (a Hash by name) for the
      # attributes it has, or this builder if +types+ has none of them.
      # The copy keeps the same #indexes, so rows laid out for this builder
      # work with it.
      def with_types(types)
        overrides = types.select { |name, _| @indexes.key?(name) }
        return self if overrides.empty?

        copy = dup
        copy.types = @types.merge(overrides)
        copy.from_db_context = FromDBContext.new(@names, copy.types, @defaults, @default_keys)
        copy.freeze
      end

      # Converts +column_types+, a Hash of types by name, into the
      # +additional_types+ for a row laid out with +indexes+ (see
      # #build_from_database).
      def additional_types_for(indexes, column_types)
        return EMPTY_TYPES if column_types.empty? || !indexes.is_a?(IndexedRow::ExtendedIndexes)

        types = []
        indexes.extra.each do |name, ord|
          types[ord - @names.size] = column_types[name] if ord >= @names.size
        end
        types
      end

      protected
        attr_writer :types, :from_db_context

      private
        def names_for(indexes)
          names = []
          indexes.each_key { |name| names[indexes[name].ord] = name }
          names.freeze
        end

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
