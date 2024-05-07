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
  #   # ActiveRecord::Result also includes Enumerable.
  #   result.each do |row|
  #     puts row['title'] + " " + row['body']
  #   end
  class Result
    include Enumerable

    attr_reader :columns, :rows, :column_types

    def self.empty(async: false) # :nodoc:
      if async
        EMPTY_ASYNC
      else
        EMPTY
      end
    end

    def initialize(columns, rows, column_types = nil)
      # We freeze the strings to prevent them getting duped when
      # used as keys in ActiveRecord::Base's @attributes hash
      @columns      = columns.each(&:-@).freeze
      @rows         = rows
      @hash_rows    = nil
      @column_types = column_types || EMPTY_HASH
      @column_indexes = nil
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
    # row as parameter.
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

    def result # :nodoc:
      self
    end

    def cancel # :nodoc:
      self
    end

    def cast_values(type_overrides = {}) # :nodoc:
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
      @columns      = columns
      @rows         = rows.dup
      @column_types = column_types.dup
      @hash_rows    = nil
    end

    def freeze # :nodoc:
      hash_rows.freeze
      super
    end

    def column_indexes # :nodoc:
      @column_indexes ||= begin
        index = 0
        hash = {}
        length  = columns.length
        while index < length
          hash[columns[index]] = index
          index += 1
        end
        hash
      end
    end

    private
      def column_type(name, index, type_overrides)
        type_overrides.fetch(name) do
          column_types.fetch(index) do
            column_types.fetch(name, Type.default_value)
          end
        end
      end

      def hash_rows
        # We use transform_values to rows.
        # This is faster because we avoid any reallocs and avoid hashing entirely.
        @hash_rows ||= @rows.map do |row|
          column_indexes.transform_values { |index| row[index] }
        end
      end

      empty_array = [].freeze
      EMPTY_HASH = {}.freeze
      private_constant :EMPTY_HASH

      EMPTY = new(empty_array, empty_array, EMPTY_HASH).freeze
      private_constant :EMPTY

      EMPTY_ASYNC = FutureResult.wrap(EMPTY).freeze
      private_constant :EMPTY_ASYNC
  end
end
