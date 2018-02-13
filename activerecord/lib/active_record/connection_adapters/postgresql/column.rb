# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      delegate :array, :oid, :fmod, to: :sql_type_metadata
      alias :array? :array

      def initialize(*, max_identifier_length: 63, **)
        super
        @max_identifier_length = max_identifier_length
      end

      def serial?
        return unless default_function

        if %r{\Anextval\('"?(?<sequence_name>.+_(?<suffix>seq\d*))"?'::regclass\)\z} =~ default_function
          sequence_name_from_parts(table_name, name, suffix) == sequence_name
        end
      end

      protected
        attr_reader :max_identifier_length

      private
        def sequence_name_from_parts(table_name, column_name, suffix)
          over_length = [table_name, column_name, suffix].map(&:length).sum + 2 - max_identifier_length

          if over_length > 0
            column_name_length = [(max_identifier_length - suffix.length - 2) / 2, column_name.length].min
            over_length -= column_name.length - column_name_length
            column_name = column_name[0, column_name_length - [over_length, 0].min]
          end

          if over_length > 0
            table_name = table_name[0, table_name.length - over_length]
          end

          "#{table_name}_#{column_name}_#{suffix}"
        end
    end
  end
end
