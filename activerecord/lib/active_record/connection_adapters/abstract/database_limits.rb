module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseLimits

      # the maximum length of a table alias
      def table_alias_length
        255
      end

      # the maximum length of a column name
      def column_name_length
        64
      end

      # the maximum length of a table name
      def table_name_length
        64
      end

      # the maximum length of an index name
      def index_name_length
        64
      end

      # the maximum number of columns per table
      def columns_per_table
        1024
      end

      # the maximum number of indexes per table
      def indexes_per_table
        16
      end

      # the maximum number of columns in a multicolumn index
      def columns_per_multicolumn_index
        16
      end

      # the maximum number of elements in an IN (x,y,z) clause
      def in_clause_length
        65535
      end

      # the maximum length of a SQL query
      def sql_query_length
        1048575
      end

      # maximum number of joins in a single query
      def joins_per_query
        256
      end

    end
  end
end
