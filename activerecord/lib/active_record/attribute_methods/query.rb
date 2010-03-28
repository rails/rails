require 'active_support/core_ext/object/blank'

module ActiveRecord
  module AttributeMethods
    module Query
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "?"
      end

      def query_attribute(attr_name)
        unless value = read_attribute(attr_name)
          false
        else
          column = self.class.columns_hash[attr_name]
          if column.nil?
            if Numeric === value || value !~ /[^0-9]/
              !value.to_i.zero?
            else
              return false if ActiveRecord::ConnectionAdapters::Column::FALSE_VALUES.include?(value)
              !value.blank?
            end
          elsif column.number?
            !value.zero?
          else
            !value.blank?
          end
        end
      end

      private
        # Handle *? for method_missing.
        def attribute?(attribute_name)
          query_attribute(attribute_name)
        end
    end
  end
end
