module ActiveRecord
  ###
  # This class encapsulates a Result returned from calling +exec+ on any
  # database connection adapter.  For example:
  #
  #   x = ActiveRecord::Base.connection.exec('SELECT * FROM foo')
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

    private
    def hash_rows
      @hash_rows ||= @rows.map { |row|
        ActiveSupport::OrderedHash[@columns.zip(row)]
      }
    end
  end
end
