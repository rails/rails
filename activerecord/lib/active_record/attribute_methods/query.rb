# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods \Query
    module Query
      extend ActiveSupport::Concern

      included do
        include ActiveModel::AttributeMethods::Query
      end

      def _query_attribute(attr_name) # :nodoc:
        value = self._read_attribute(attr_name.to_s)

        query_cast_attribute(attr_name, value)
      end
    end
  end
end
