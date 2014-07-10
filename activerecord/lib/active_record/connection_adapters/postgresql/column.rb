module ActiveRecord
  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      attr_accessor :array

      def initialize(name, default, cast_type, sql_type = nil, null = true, default_function = nil)
        if sql_type =~ /\[\]$/
          @array = true
          super(name, default, cast_type, sql_type[0..sql_type.length - 3], null)
        else
          @array = false
          super(name, default, cast_type, sql_type, null)
        end

        @default_function = default_function
      end
    end
  end
end
