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

      # Returns the maximum length of an index name.
      def index_name_length
        max_identifier_length
      end

      # Returns the maximum number of elements in an IN (x,y,z) clause.
      # +nil+ means no limit.
      def in_clause_length
        nil
      end
      deprecate :in_clause_length

      private
        def bind_params_length
          65535
        end
    end
  end
end
