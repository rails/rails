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
