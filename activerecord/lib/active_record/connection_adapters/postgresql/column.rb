require 'active_record/connection_adapters/postgresql/cast'

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

      # :stopdoc:
      class << self
        include PostgreSQL::Cast

        # Loads pg_array_parser if available. String parsing can be
        # performed quicker by a native extension, which will not create
        # a large amount of Ruby objects that will need to be garbage
        # collected. pg_array_parser has a C and Java extension
        begin
          require 'pg_array_parser'
          include PgArrayParser
        rescue LoadError
          require 'active_record/connection_adapters/postgresql/array_parser'
          include PostgreSQL::ArrayParser
        end
      end
      # :startdoc:

      def accessor
        cast_type.accessor
      end
    end
  end
end
