module ActiveRecord
  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      delegate :array, :oid, :fmod, to: :sql_type_metadata
      alias :array? :array

      def serial?
        default_function && default_function =~ /\Anextval\(.*\)\z/
      end
    end
  end
end
