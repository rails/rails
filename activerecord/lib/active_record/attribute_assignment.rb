# frozen_string_literal: true

require "active_model/forbidden_attributes_protection"
require "active_model/multiparameter_attribute_assignment"

module ActiveRecord
  module AttributeAssignment
    include ActiveModel::MultiparameterAttributeAssignment

    private

      def _assign_attributes(attributes)
        nested_parameter_attributes = {}

        attributes.each do |k, v|
          if v.is_a?(Hash)
            nested_parameter_attributes[k] = attributes.delete(k)
          end
        end
        super(attributes)

        assign_nested_parameter_attributes(nested_parameter_attributes) unless nested_parameter_attributes.empty?
      end

      # Assign any deferred nested attributes after the base attributes have been set.
      def assign_nested_parameter_attributes(pairs)
        pairs.each { |k, v| _assign_attribute(k, v) }
      end

      def attribute_assignment_error_class
        ::ActiveRecord::AttributeAssignmentError
      end

      def multiparameter_assignment_errors_class
        ::ActiveRecord::MultiparameterAssignmentErrors
      end
  end
end
