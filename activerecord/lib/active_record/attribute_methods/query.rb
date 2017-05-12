module ActiveRecord
  module AttributeMethods
    module Query
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "?"
      end

      def query_attribute(attr_name)
        ActiveSupport::Deprecation.warn(<<-EOW.squish)
          Query attribute methods(like `attribute?`) will not behave like
          using `ActiveModel::Type::Boolean` and will be shortcuts
          for `attribute.present?` in the next version of Rails.
          If you'd like #{attr_name}? to return false for values defined
          in `ActiveModel::Type::Boolean::FALSE_VALUES`, use
          `ActiveModel::Type::Boolean` instead.
        EOW

        value = self[attr_name]

        case value
        when true        then true
        when false, nil  then false
        else
          column = self.class.columns_hash[attr_name]
          if column.nil?
            if Numeric === value || value !~ /[^0-9]/
              !value.to_i.zero?
            else
              return false if ActiveModel::Type::Boolean::FALSE_VALUES.include?(value)
              !value.blank?
            end
          elsif value.respond_to?(:zero?)
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
