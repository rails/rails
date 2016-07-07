module ActiveRecord
  ###
  # This class encapsulates a result returned from calling
  # {#exec_query}[rdoc-ref:ConnectionAdapters::DatabaseStatements#exec_query]
  # on any database connection adapter. For example:
  #
  #   result = ActiveRecord::Base.connection.exec_query('SELECT id, title, body FROM posts')
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
  #   result.to_hash
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

    IDENTITY_TYPE = Type::Value.new # :nodoc:

    attr_reader :columns, :rows, :column_types

    def initialize(columns, rows, column_types = {})
      @columns      = columns
      @rows         = rows
      @hash_rows    = nil
      @column_types = column_types
    end

    def length
      @rows.length
    end

    def each
      if block_given?
        hash_rows.each { |row| yield row }
      else
        hash_rows.to_enum { @rows.size }
      end
    end

    def to_hash
      hash_rows
    end

    alias :map! :map
    alias :collect! :map

    # Returns true if there are no records.
    def empty?
      rows.empty?
    end

    def to_ary
      hash_rows
    end

    def [](idx)
      hash_rows[idx]
    end

    def first
      return nil if @rows.empty?
      Hash[@columns.zip(@rows.first)]
    end

    def last
      return nil if @rows.empty?
      Hash[@columns.zip(@rows.last)]
    end

    def cast_values(type_overrides = {}) # :nodoc:
      types = columns.map { |name| column_type(name, type_overrides) }
      result = rows.map do |values|
        types.zip(values).map { |type, value| type.deserialize(value) }
      end

      columns.one? ? result.map!(&:first) : result
    end

    def initialize_copy(other)
      @columns      = columns.dup
      @rows         = rows.dup
      @column_types = column_types.dup
      @hash_rows    = nil
    end

    private

    def column_type(name, type_overrides = {})
      type_overrides.fetch(name) do
        column_types.fetch(name, IDENTITY_TYPE)
      end
    end

    def hash_rows
      @hash_rows ||=
        begin
          # We freeze the strings to prevent them getting duped when
          # used as keys in ActiveRecord::Base's @attributes hash
          columns = @columns.map { |c| c.dup.freeze }
          @rows.map { |row|
            # In the past we used Hash[columns.zip(row)]
            #  though elegant, the verbose way is much more efficient
            #  both time and memory wise cause it avoids a big array allocation
            #  this method is called a lot and needs to be micro optimised
            hash = {}

            index = 0
            length = columns.length

            while index < length
              hash[columns[index]] = row[index]
              index += 1
            end

            hash
          }
        end
    end
  end
end
