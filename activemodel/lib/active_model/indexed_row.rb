# frozen_string_literal: true

# :markup: markdown

module ActiveModel
  class IndexedRow # :nodoc:
    UNSET = Module.new.freeze
    private_constant :UNSET

    class << self
      # A row of +size+ slots that are all unset, to be filled in by position.
      def unset_row(size)
        Array.new(size, UNSET)
      end

      # The largest slot in +indexes+, or -1 if it is empty.
      def max_slot(indexes)
        indexes.each_value.max || -1
      end

      # Whether +row+, an Array laid out by slot, has a value at +index+.
      def key_at?(row, index)
        index < row.size && !UNSET.equal?(row[index])
      end

      def [](hash)
        return hash if hash.is_a?(self)

        index = -1
        column_indexes = hash.transform_values { index += 1 }.freeze
        new(column_indexes, hash.values.freeze)
      end

      def build_indexes(columns)
        index = -1
        columns.index_with { index += 1 }
      end
    end

    attr_reader :indexes, :row

    def initialize(indexes, row)
      @indexes = indexes
      @row = row
    end

    def size
      keys.size
    end
    alias_method :length, :size

    def each_key(&block)
      keys.each(&block)
    end

    def keys
      keys = []
      @indexes.each_key { |column| keys << column if key?(column) }
      keys
    end

    def values
      @row.reject { |v| UNSET.equal?(v) }
    end

    def values_at(*columns)
      columns.map! do |column|
        if index = index_for(column)
          @row[index]
        end
      end
      columns
    end

    def ==(other)
      case other
      when Hash
        to_hash == other
      when IndexedRow
        to_hash == other.to_hash
      else
        false
      end
    end

    def hash
      [IndexedRow, @indexes, @row].hash
    end

    def eql?(other)
      other.is_a?(IndexedRow) &&
        @indexes == other.indexes &&
        @row == other.row
    end

    def key?(column)
      !index_for(column).nil?
    end

    def fetch(column)
      if index = index_for(column)
        @row[index]
      elsif block_given?
        yield
      else
        raise KeyError, "key not found: #{column.inspect}"
      end
    end

    def [](column)
      if index = index_for(column)
        @row[index]
      end
    end

    # Like #fetch, but looks the value up by its slot in the row
    # rather than by name.
    def fetch_at(index)
      value = index < @row.size ? @row[index] : UNSET

      if !UNSET.equal?(value)
        value
      elsif block_given?
        yield
      else
        raise KeyError, "index not found: #{index.inspect}"
      end
    end

    # Like #[], but looks the value up by its slot in the row
    # rather than by name.
    def at(index)
      value = @row[index]
      value unless UNSET.equal?(value)
    end

    # Like #key?, but looks the column up by its index in the row.
    def key_at?(index)
      IndexedRow.key_at?(@row, index)
    end

    def to_h
      transform_values(&:itself)
    end
    alias_method :to_hash, :to_h

    def each_value
      return enum_for(:each_value) { size } unless block_given?

      @indexes.each_key do |column|
        if index = index_for(column)
          yield @row[index]
        end
      end
      self
    end

    def transform_values
      return enum_for(:transform_values) { size } unless block_given?

      hash = {}
      @indexes.each_key do |column|
        if index = index_for(column)
          hash[column] = yield(@row[index])
        end
      end
      hash
    end

    # Like #transform_values, but returns a Mutable row with the same
    # indexes, so the new row keeps the same layout.
    def transform_row
      return enum_for(:transform_row) { size } unless block_given?

      Mutable.new(@indexes, @row.map { |value| UNSET.equal?(value) ? value : yield(value) })
    end

    def except(*columns)
      to_h.except(*columns)
    end

    # Builds rows keyed by +new_columns+ out of rows keyed by +old_columns+.
    #
    # When +column_map+ is given, the new rows are laid out by the slot of
    # each column in it, and columns it doesn't have are given indexes after
    # its last one (see ExtendedIndexes). Without one, every column is
    # extra, so the new row is in the order of +new_columns+.
    class Remapper
      EMPTY = {}.freeze
      private_constant :EMPTY

      def initialize(initial_indexes, old_columns, new_columns = old_columns, column_map = EMPTY)
        # Handle duplicate keys
        pairs = new_columns.zip(old_columns).to_h

        extra = nil
        last_slot = nil

        # [slot in the new row, index in the original row]
        slots = pairs.map do |new_column, old_column|
          unless slot = column_map[new_column]
            extra ||= {}
            last_slot ||= IndexedRow.max_slot(column_map)
            slot = extra[new_column] = (last_slot += 1)
          end

          [slot, initial_indexes.fetch(old_column)]
        end
        slots.sort_by!(&:first)

        @new_indexes = if extra.nil?
          column_map
        elsif column_map.empty?
          extra.freeze
        else
          ExtendedIndexes.new(column_map, extra.freeze)
        end

        # If the new row has no gaps, it can be built with a single
        # values_at. Otherwise fill in an unset row by position.
        if slots.each_with_index.all? { |(slot, _), i| slot == i }
          @indexes_to_extract = slots.map(&:last)
          @slots = nil
        else
          @slots = slots
          @width = slots.last.first + 1
        end
      end

      def build(original_row)
        values = original_row.row

        if @slots
          row = IndexedRow.unset_row(@width)
          @slots.each { |slot, index| row[slot] = values[index] }
        else
          row = values.values_at(*@indexes_to_extract)
        end

        IndexedRow.new(@new_indexes, row.freeze)
      end
    end

    # Wraps an immutable column map and adds indexes for columns it doesn't
    # have, such as aliases selected alongside a model's columns. The query
    # that selected those columns can also say what type each one is.
    class ExtendedIndexes
      EMPTY_TYPES = {}.freeze
      private_constant :EMPTY_TYPES

      # Returns +indexes+ with +column+ added at +index+, without modifying
      # +indexes+.
      def self.add(indexes, column, index)
        if indexes.is_a?(self)
          new(indexes.indexes, indexes.extra.merge(column => index).freeze, indexes.extra_types)
        else
          new(indexes, { column => index }.freeze)
        end
      end

      attr_reader :indexes, :extra, :extra_types

      # +extra_types+ has the types of the +extra+ columns that have one, by
      # slot.
      def initialize(indexes, extra, extra_types = EMPTY_TYPES)
        @indexes = indexes
        @extra = extra
        @extra_types = extra_types
        freeze
      end

      # The type of the extra column at +slot+, if it has one.
      def type_at(slot)
        @extra_types[slot]
      end

      def [](column)
        @indexes[column] || @extra[column]
      end

      def fetch(column, &block)
        @indexes.fetch(column) { @extra.fetch(column, &block) }
      end

      def key?(column)
        @indexes.key?(column) || @extra.key?(column)
      end

      def each_key(&block)
        return enum_for(:each_key) { size } unless block

        @indexes.each_key(&block)
        @extra.each_key(&block)
        self
      end

      def keys
        @indexes.keys + @extra.keys
      end

      def each_value(&block)
        return enum_for(:each_value) { size } unless block

        @indexes.each_value(&block)
        @extra.each_value(&block)
        self
      end

      def size
        @indexes.size + @extra.size
      end

      def ==(other)
        other.is_a?(ExtendedIndexes) && @indexes == other.indexes && @extra == other.extra &&
          @extra_types == other.extra_types
      end
      alias_method :eql?, :==

      def hash
        [ExtendedIndexes, @indexes, @extra, @extra_types].hash
      end
    end

    class Mutable < self
      # Builds a Mutable row from a Hash, indexed in the Hash's order.
      def self.[](hash)
        return hash if hash.is_a?(self)

        new(IndexedRow.build_indexes(hash.keys).freeze, hash.values)
      end

      def initialize(indexes, row = nil, size: indexes.size)
        @indexes = indexes
        @row = row || IndexedRow.unset_row(size)
      end

      def initialize_copy(other)
        super
        @row = @row.dup
      end

      def freeze
        @row.freeze
        super
      end

      def size
        @row.size - @row.count(UNSET)
      end
      alias_method :length, :size

      # Columns that aren't in the indexes are added after the last index.
      # The indexes are replaced rather than modified, since they're usually
      # shared with other rows.
      def []=(column, value)
        unless index = @indexes[column]
          index = [@row.size, IndexedRow.max_slot(@indexes) + 1].max
          @indexes = ExtendedIndexes.add(@indexes, column, index)
        end

        if index >= @row.size
          @row.concat(IndexedRow.unset_row(index - @row.size + 1))
        end

        @row[index] = value
      end
    end

    private
      # The position of +column+ in the row, or +nil+ if the row doesn't
      # have it. A column map can include columns that weren't selected, so
      # their slot can be past the end of the row or point at an UNSET one.
      def index_for(column)
        if index = @indexes[column]
          index if index < @row.size && !UNSET.equal?(@row[index])
        end
      end
  end
end
