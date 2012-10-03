module ActiveRecord
  module AttributeMethods
    module Query
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "?"
      end

      def query_attribute(attr_name)
        value = read_attribute(attr_name) { |n| missing_attribute(n, caller) }

        case value
        when true        then true
        when false, nil  then false
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
