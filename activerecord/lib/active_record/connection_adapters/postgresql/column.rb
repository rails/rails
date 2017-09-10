# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      delegate :array, :oid, :fmod, to: :sql_type_metadata
      alias :array? :array

      def serial?
        return unless default_function

        if %r{\Anextval\('"?(?<sequence_name>.+_(?<suffix>seq\d*))"?'::regclass\)\z} =~ default_function
          sequence_name_from_parts(table_name, name, suffix) == sequence_name
        end
      end

      private
        def sequence_name_from_parts(table_name, column_name, suffix)
          "#{table_name}_#{column_name}_#{suffix}"
        end
    end
  end
end
