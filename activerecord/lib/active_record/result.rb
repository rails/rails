module ActiveRecord
  ###
  # This class encapsulates a Result returned from calling +exec_query+ on any
  # database connection adapter. For example:
  #
  #   x = ActiveRecord::Base.connection.exec_query('SELECT * FROM foo')
  #   x # => #<ActiveRecord::Result:0xdeadbeef>
  class Result
    include Enumerable

    attr_reader :columns, :rows

    def initialize(columns, rows)
      @columns   = columns
      @rows      = rows
      @hash_rows = nil
    end

    def each
      hash_rows.each { |row| yield row }
    end

    def to_hash
      hash_rows
    end

    private
    def hash_rows
      @hash_rows ||=
        begin
          # We freeze the strings to prevent them getting duped when
          # used as keys in ActiveRecord::Model's @attributes hash
          columns = @columns.map { |c| c.dup.freeze }
          @rows.map { |row|
            Hash[columns.zip(row)]
          }
        end
    end
  end
end
