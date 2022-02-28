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

      private
        def bind_params_length
          65535
        end
    end
  end
end
