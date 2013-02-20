module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module DatabaseLimits

      # Returns the maximum length of a table alias.
      def table_alias_length
        255
      end

      # Returns the maximum length of a column name.
      def column_name_length
        64
      end

      # Returns the maximum length of a table name.
      def table_name_length
        64
      end

      # Returns the maximum allowed length for an index name. This
      # limit is enforced by rails and Is less than or equal to
      # <tt>index_name_length</tt>. The gap between
      # <tt>index_name_length</tt> is to allow internal rails
      # opreations to use prefixes in temporary opreations.
      def allowed_index_name_length
        index_name_length
      end

      # Returns the maximum length of an index name.
      def index_name_length
        64
      end

      # Returns the maximum number of columns per table.
      def columns_per_table
        1024
      end

      # Returns the maximum number of indexes per table.
      def indexes_per_table
        16
      end

      # Returns the maximum number of columns in a multicolumn index.
      def columns_per_multicolumn_index
        16
      end

      # Returns the maximum number of elements in an IN (x,y,z) clause.
      # nil means no limit.
      def in_clause_length
        nil
      end

      # Returns the maximum length of an SQL query.
      def sql_query_length
        1048575
      end

      # Returns maximum number of joins in a single query.
      def joins_per_query
        256
      end

    end
  end
end
