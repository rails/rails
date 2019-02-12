# frozen_string_literal: true

require "active_model/forbidden_attributes_protection"

module ActiveRecord
  module AttributeAssignment
    include ActiveModel::AttributeAssignment

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
  end
end
