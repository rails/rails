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

      # The largest +ord+ in +column_map+, or -1 if it is empty.
      def max_ord(column_map)
        column_map.each_value.inject(-1) { |max, column| column.ord > max ? column.ord : max }
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
      @indexes.each_key.select { |column| key?(column) }
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
      if other.is_a?(Hash)
        to_hash == other
      else
        super
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

    # Like #fetch, but looks the value up by its index in the row (the
    # column's +ord+) rather than by name.
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

    # Like #[], but looks the value up by its index in the row (the
    # column's +ord+) rather than by name.
    def at(index)
      value = @row[index]
      value unless UNSET.equal?(value)
    end

    def to_h
      keys.index_with { |column| @row[index_for(column)] }
    end
    alias_method :to_hash, :to_h

    def new_empty_mutable_row
      Mutable.new(@indexes, size: @row.size)
    end

    # Builds rows keyed by +new_columns+ out of rows keyed by +old_columns+.
    #
    # When +column_map+ is given, the new rows are laid out by the +ord+ of
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
        last_ord = nil

        # [ord in the new row, index in the original row]
        slots = pairs.map do |new_column, old_column|
          if column = column_map[new_column]
            ord = column.ord
          else
            extra ||= {}
            last_ord ||= IndexedRow.max_ord(column_map)
            ord = extra[new_column] = (last_ord += 1)
          end

          [ord, initial_indexes.fetch(old_column).ord]
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
        if slots.each_with_index.all? { |(ord, _), i| ord == i }
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
          @slots.each { |ord, index| row[ord] = values[index] }
        else
          row = values.values_at(*@indexes_to_extract)
        end

        IndexedRow.new(@new_indexes, row.freeze)
      end
    end

    # Wraps an immutable column map and adds indexes for columns it doesn't
    # have, such as aliases selected alongside a model's columns.
    class ExtendedIndexes
      def initialize(indexes, extra)
        @indexes = indexes
        @extra = extra
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

      def size
        @indexes.size + @extra.size
      end
    end

    class Mutable < self
      def initialize(indexes, row = nil, size: indexes.size)
        @indexes = indexes
        @row = row || IndexedRow.unset_row(size)
      end

      def size
        @row.size - @row.count(UNSET)
      end
      alias_method :length, :size

      def []=(column, value)
        if (entry = @indexes[column]) && (index = entry.ord) < @row.size
          @row[index] = value
        else
          raise KeyError, "key not found: #{column.inspect}"
        end
      end
    end

    private
      # The position of +column+ in the row, or +nil+ if the row doesn't
      # have it. The values in +@indexes+ are either Integers or Columns
      # (both respond to +ord+). A column map can include columns that
      # weren't selected, so their +ord+ can be past the end of the row or
      # point at an UNSET slot.
      def index_for(column)
        if entry = @indexes[column]
          index = entry.ord
          index if index < @row.size && !UNSET.equal?(@row[index])
        end
      end
  end
end
