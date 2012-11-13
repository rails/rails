module ActiveRecord
  ###
  # This class encapsulates a Result returned from calling +exec_query+ on any
  # database connection adapter. For example:
  #
  #   x = ActiveRecord::Base.connection.exec_query('SELECT * FROM foo')
  #   x # => #<ActiveRecord::Result:0xdeadbeef>
  class Result
    include Enumerable

    attr_reader :columns, :rows, :column_types

    def initialize(columns, rows, column_types = {})
      @columns      = columns
      @rows         = rows
      @hash_rows    = nil
      @column_types = column_types
    end

    def each
      hash_rows.each { |row| yield row }
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

    def last
      hash_rows.last
    end

    def initialize_copy(other)
      @columns   = columns.dup
      @rows      = rows.dup
      @hash_rows = nil
    end

    private
    def hash_rows
      @hash_rows ||=
        begin
          # We freeze the strings to prevent them getting duped when
          # used as keys in ActiveRecord::Base's @attributes hash
          columns = @columns.map { |c| c.dup.freeze }
          @rows.map { |row|
            Hash[columns.zip(row)]
          }
        end
    end
  end
end
