# frozen_string_literal: true

module ActiveRecord
  ###
  # Active Record \Result
  # =====================
  #
  # This class encapsulates a result returned from calling
  # [#exec_query](rdoc-ref:ConnectionAdapters::DatabaseStatements#exec_query)
  # on any database connection adapter. For example:
  #
  # ```
  # result = ActiveRecord::Base.lease_connection.exec_query('SELECT id, title, body FROM posts')
  # result # => #<ActiveRecord::Result:0xdeadbeef>
  #
  # # Get the column names of the result:
  # result.columns
  # # => ["id", "title", "body"]
  #
  # # Get the record values of the result:
  # result.rows
  # # => [[1, "title_1", "body_1"],
  #       [2, "title_2", "body_2"],
  #       ...
  #      ]
  #
  # # Get an array of hashes representing the result (column => value):
  # result.to_a
  # # => [{"id" => 1, "title" => "title_1", "body" => "body_1"},
  #       {"id" => 2, "title" => "title_2", "body" => "body_2"},
  #       ...
  #      ]
  #
  # # Get the number of rows affected by the query:
  # result = ActiveRecord::Base.lease_connection.exec_query('INSERT INTO posts (title, body) VALUES ("title_3", "body_3"), ("title_4", "body_4")')
  # result.affected_rows
  # # => 2
  #
  # # ActiveRecord::Result also includes Enumerable.
  # result.each do |row|
  #   puts row['title'] + " " + row['body']
  # end
  # ```
  class Result
    include Enumerable

    attr_reader :columns, :rows, :affected_rows

    def self.empty(async: false, affected_rows: nil) # :nodoc:
      if async
        FutureResult.wrap(new(EMPTY_ARRAY, EMPTY_ARRAY, EMPTY_HASH, affected_rows: affected_rows)).freeze
      else
        new(EMPTY_ARRAY, EMPTY_ARRAY, EMPTY_HASH, affected_rows: affected_rows).freeze
      end
    end

    def initialize(columns, rows, column_types = nil, affected_rows: nil)
      @columns      = columns.freeze
      @rows         = rows
      @hash_rows    = nil
      @column_types = column_types.freeze
      @types_hash   = nil
      @column_indexes = nil
      @affected_rows = affected_rows
    end

    def raw_column_types
      @column_types
    end

    # Returns true if this result set includes the column named `name`
    def includes_column?(name)
      @columns.include? name
    end

    # Returns the number of elements in the rows array.
    def length
      @rows.length
    end

    # Calls the given block once for each element in row collection, passing
    # row as parameter. Each row is a Hash-like, read only object.
    #
    # To get real hashes, use `.to_a.each`.
    #
    # Returns an `Enumerator` if no block is given.
    def each(&block)
      if block_given?
        hash_rows.each(&block)
      else
        hash_rows.to_enum { @rows.size }
      end
    end

    # Returns true if there are no records, otherwise false.
    def empty?
      rows.empty?
    end

    # Returns an array of hashes representing each row record.
    def to_ary
      hash_rows
    end

    alias :to_a :to_ary

    def [](idx)
      hash_rows[idx]
    end

    # Returns the last record from the rows collection.
    def last(n = nil)
      n ? hash_rows.last(n) : hash_rows.last
    end

    # Returns the `ActiveRecord::Type` type of all columns.
    # Note that not all database adapters return the result types,
    # so the hash may be empty.
    def column_types
      if @column_types
        @types_hash ||= begin
          types = {}
          @columns.each_with_index do |name, index|
            type = @column_types[index] || Type.default_value
            types[name] = types[index] = type
          end
          types.freeze
        end
      else
        EMPTY_HASH
      end
    end

    def each_pair
      if @column_types
        @columns.each_with_index do |name, index|
          type = @column_types[index] || Type.default_value
          yield(name, type)
        end
      end
    end

    # Same as column_types, but no integer based indexes.  The value isn't
    # cached, so avoid repeated calls.
    def column_types_by_name # :nodoc:
      if @column_types
        types = {}
        @columns.each_with_index do |name, index|
          type = @column_types[index] || Type.default_value
          types[name] = type
        end
        types.freeze
      else
        EMPTY_HASH
      end
    end

    def result # :nodoc:
      self
    end

    def cancel # :nodoc:
      self
    end

    def cast_values(type_overrides = nil) # :nodoc:
      if columns.one?
        # Separated to avoid allocating an array per row

        type = if type_overrides.is_a?(Array)
          type_overrides.first
        else
          column_type(columns.first, 0, type_overrides)
        end

        rows.map do |(value)|
          type.deserialize(value)
        end
      else
        types = if type_overrides.is_a?(Array)
          type_overrides
        else
          columns.map.with_index { |name, i| column_type(name, i, type_overrides) }
        end

        rows.map do |values|
          Array.new(values.size) { |i| types[i].deserialize(values[i]) }
        end
      end
    end

    def initialize_copy(other)
      @rows = rows.dup
      @hash_rows = nil
      @indexed_rows = nil
    end

    def shuffle_rows(arel) # :nodoc:
      return self if rows.size < 2
      return self unless ConnectionAdapters::QueryIntent.shuffle_rows?(arel)

      dup.shuffle!
    end

    def shuffle! # :nodoc:
      @rows = @rows.shuffle
      self
    end

    def freeze # :nodoc:
      hash_rows.freeze
      indexed_rows
      column_types
      super
    end

    def column_indexes # :nodoc:
      @column_indexes ||= ActiveModel::IndexedRow.build_indexes(columns)
    end

    def map_rows(column_map) # :nodoc:
      layout = RowLayout.new(@columns, column_map)
      @rows.map { |row| yield layout.build(row) }
    end

    # Like #map_rows, but each row is laid out for the column map that
    # +column_map_for+ returns for that row's value of +column_name+, and
    # that value is yielded with the row. +column_map_for+ is called once
    # for each distinct value.
    def map_rows_by(column_name, column_map_for) # :nodoc:
      index = @columns.index(column_name)
      layouts = {}

      @rows.map do |row|
        value = row[index]
        layout = layouts[value] ||= RowLayout.new(@columns, column_map_for.call(value))
        yield layout.build(row), value
      end
    end

    def indexed_rows # :nodoc:
      @indexed_rows ||= begin
        columns = column_indexes
        @rows.map { |row| ActiveModel::IndexedRow.new(columns, row) }.freeze
      end
    end

    # Lays rows out the way a column map expects. The +ord+ method on each
    # column corresponds to the index generated in the reader/writer
    # methods, so the values in a row need to line up with those indexes.
    #
    # "Pending" columns are columns the schema didn't know about, so no
    # methods were generated for them, for example column aliases. They
    # are given indexes after the last one in the column map, and rows get
    # a proxy that wraps the column map with those extra indexes, so the
    # column map itself is never modified.
    #
    # The LUT is only built once a column is found out of place, so in the
    # common case (selected columns are in schema order) rows are used
    # as-is.
    class RowLayout # :nodoc:
      def initialize(columns, column_map)
        shuffle_lut = nil
        pending = nil
        last_ord = nil

        columns.each_with_index do |name, i|
          if column = column_map[name]
            ord = column.ord
          else
            pending ||= {}
            last_ord ||= ActiveModel::IndexedRow.max_ord(column_map)
            ord = pending[name] = (last_ord += 1)
          end

          if shuffle_lut
            shuffle_lut << ord
          elsif ord != i
            shuffle_lut = (0...i).to_a << ord
          end
        end

        @indexes = if pending
          ActiveModel::IndexedRow::ExtendedIndexes.new(column_map, pending.freeze)
        else
          column_map
        end
        @shuffle_lut = shuffle_lut
        @width = shuffle_lut.max + 1 if shuffle_lut
      end

      def build(row)
        if @shuffle_lut
          shuffled = ActiveModel::IndexedRow.unset_row(@width)
          @shuffle_lut.each_with_index { |ord, i| shuffled[ord] = row[i] }
          row = shuffled.freeze
        end
        ActiveModel::IndexedRow.new(@indexes, row)
      end
    end

    private
      def column_type(name, index, type_overrides)
        if type_overrides
          type_overrides.fetch(name) do
            column_type(name, index, nil)
          end
        elsif @column_types
          @column_types[index] || Type.default_value
        else
          Type.default_value
        end
      end

      def hash_rows
        # We use transform_values to rows.
        # This is faster because we avoid any reallocs and avoid hashing entirely.
        @hash_rows ||= @rows.map do |row|
          column_indexes.transform_values { |index| row[index] }
        end
      end

      EMPTY_ARRAY = [].freeze
      EMPTY_HASH = {}.freeze
      private_constant :EMPTY_ARRAY, :EMPTY_HASH
  end
end
