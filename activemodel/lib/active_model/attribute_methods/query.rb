# frozen_string_literal: true

module ActiveModel
  module AttributeMethods
    # = Active Model Attribute Methods \Query
    module Query
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "?", parameters: false
      end

      def query_attribute(attr_name)
        value = self.public_send(attr_name)

        query_cast_attribute(attr_name, value)
      end

      alias :attribute? :query_attribute
      private :attribute?

      private
        def query_cast_attribute(attr_name, value)
          case value
          when true        then true
          when false, nil  then false
          else
            if !self.class.type_for_attribute(attr_name) { false }
              if Numeric === value || !value.to_s.match?(/[^0-9]/)
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
    end
  end
end
