# frozen_string_literal: true

module ActiveRecord
  ###
  # = Active Record \Result
  #
  # This class encapsulates a result returned from calling
  # {#exec_query}[rdoc-ref:ConnectionAdapters::DatabaseStatements#exec_query]
  # on any database connection adapter. For example:
  #
  #   result = ActiveRecord::Base.lease_connection.exec_query('SELECT id, title, body FROM posts')
  #   result # => #<ActiveRecord::Result:0xdeadbeef>
  #
  #   # Get the column names of the result:
  #   result.columns
  #   # => ["id", "title", "body"]
  #
  #   # Get the record values of the result:
  #   result.rows
  #   # => [[1, "title_1", "body_1"],
  #         [2, "title_2", "body_2"],
  #         ...
  #        ]
  #
  #   # Get an array of hashes representing the result (column => value):
  #   result.to_a
  #   # => [{"id" => 1, "title" => "title_1", "body" => "body_1"},
  #         {"id" => 2, "title" => "title_2", "body" => "body_2"},
  #         ...
  #        ]
  #
  #   # Get the number of rows affected by the query:
  #   result = ActiveRecord::Base.lease_connection.exec_query('INSERT INTO posts (title, body) VALUES ("title_3", "body_3"), ("title_4", "body_4")')
  #   result.affected_rows
  #   # => 2
  #
  #   # ActiveRecord::Result also includes Enumerable.
  #   result.each do |row|
  #     puts row['title'] + " " + row['body']
  #   end
  class Result
    include Enumerable

    class IndexedRow
      def initialize(column_indexes, row)
        @column_indexes = column_indexes
        @row = row
      end

      def size
        @column_indexes.size
      end
      alias_method :length, :size

      def each_key(&block)
        @column_indexes.each_key(&block)
      end

      def keys
        @column_indexes.keys
      end

      def ==(other)
        if other.is_a?(Hash)
          to_hash == other
        else
          super
        end
      end

      def key?(column)
        @column_indexes.key?(column)
      end

      def fetch(column)
        if index = @column_indexes[column]
          @row[index]
        elsif block_given?
          yield
        else
          raise KeyError, "key not found: #{column.inspect}"
        end
      end

      def [](column)
        if index = @column_indexes[column]
          @row[index]
        end
      end

      def to_h
        @column_indexes.transform_values { |index| @row[index] }
      end
      alias_method :to_hash, :to_h
    end

    attr_reader :columns, :rows, :affected_rows

    def self.empty(async: false, affected_rows: nil) # :nodoc:
      if async
        FutureResult.wrap(new(EMPTY_ARRAY, EMPTY_ARRAY, EMPTY_HASH, affected_rows: affected_rows)).freeze
      else
        new(EMPTY_ARRAY, EMPTY_ARRAY, EMPTY_HASH, affected_rows: affected_rows).freeze
      end
    end

    def initialize(columns, rows, column_types = nil, affected_rows: nil)
      # We freeze the strings to prevent them getting duped when
      # used as keys in ActiveRecord::Base's @attributes hash
      @columns      = columns.each(&:-@).freeze
      @rows         = rows
      @hash_rows    = nil
      @column_types = column_types.freeze
      @types_hash   = nil
      @column_indexes = nil
      @affected_rows = affected_rows
    end

    # Returns true if this result set includes the column named +name+
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
    # To get real hashes, use +.to_a.each+.
    #
    # Returns an +Enumerator+ if no block is given.
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

    # Returns the +ActiveRecord::Type+ type of all columns.
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
      @hash_rows    = nil
    end

    def freeze # :nodoc:
      hash_rows.freeze
      indexed_rows
      column_types
      super
    end

    def column_indexes # :nodoc:
      @column_indexes ||= begin
        index = 0
        hash = {}
        length = columns.length
        while index < length
          hash[columns[index]] = index
          index += 1
        end
        hash.freeze
      end
    end

    def indexed_rows # :nodoc:
      @indexed_rows ||= begin
        columns = column_indexes
        @rows.map { |row| IndexedRow.new(columns, row) }.freeze
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
