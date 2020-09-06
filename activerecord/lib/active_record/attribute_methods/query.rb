# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    module Query
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix '?'
      end

      def query_attribute(attr_name)
        value = self[attr_name]

        case value
        when true        then true
        when false, nil  then false
        else
          if !type_for_attribute(attr_name) { false }
            if Numeric === value || !value.match?(/[^0-9]/)
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

      alias :attribute? :query_attribute
      private :attribute?
    end
  end
end
