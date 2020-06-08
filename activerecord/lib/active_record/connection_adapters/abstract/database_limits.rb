# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseLimits
      def max_identifier_length # :nodoc:
        64
      end

      # Returns the maximum length of a table alias.
      def table_alias_length
        max_identifier_length
      end

      # Returns the maximum length of a column name.
      def column_name_length
        max_identifier_length
      end
      deprecate :column_name_length

      # Returns the maximum length of a table name.
      def table_name_length
        max_identifier_length
      end
      deprecate :table_name_length

      # Returns the maximum allowed length for an index name. This
      # limit is enforced by \Rails and is less than or equal to
      # #index_name_length. The gap between
      # #index_name_length is to allow internal \Rails
      # operations to use prefixes in temporary operations.
      def allowed_index_name_length
        index_name_length
      end
      deprecate :allowed_index_name_length

      # Returns the maximum length of an index name.
      def index_name_length
        max_identifier_length
      end

      # Returns the maximum number of columns per table.
      def columns_per_table
        1024
      end
      deprecate :columns_per_table

      # Returns the maximum number of indexes per table.
      def indexes_per_table
        16
      end
      deprecate :indexes_per_table

      # Returns the maximum number of columns in a multicolumn index.
      def columns_per_multicolumn_index
        16
      end
      deprecate :columns_per_multicolumn_index

      # Returns the maximum number of elements in an IN (x,y,z) clause.
      # +nil+ means no limit.
      def in_clause_length
        nil
      end
      deprecate :in_clause_length

      # Returns the maximum length of an SQL query.
      def sql_query_length
        1048575
      end
      deprecate :sql_query_length

      # Returns maximum number of joins in a single query.
      def joins_per_query
        256
      end
      deprecate :joins_per_query

      private
        def bind_params_length
          65535
        end
    end
  end
end
