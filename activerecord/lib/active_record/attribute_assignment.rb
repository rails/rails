require 'active_model/forbidden_attributes_protection'
require 'active_model/attribute_assignment'

module ActiveRecord
  module AttributeAssignment
    extend ActiveSupport::Concern
    include ActiveModel::AttributeAssignment

    private

    def _assign_attributes(attributes) # :nodoc:
      nested_parameter_attributes = {}

      attributes.each do |k, v|
        if v.is_a?(Hash)
          nested_parameter_attributes[k] = attributes.delete(k)
        end
      end
      super(attributes)

      assign_nested_parameter_attributes(nested_parameter_attributes) unless nested_parameter_attributes.empty?
    end

    def _assign_attribute(k, v)
      if respond_to?("#{k}=")
        public_send("#{k}=", v)
      else
        raise UnknownAttributeError.new(self, k)
      end
    end

    # Assign any deferred nested attributes after the base attributes have been set.
    def assign_nested_parameter_attributes(pairs)
      pairs.each { |k, v| _assign_attribute(k, v) }
    end

    def attribute_assignment_error_klass
      ::ActiveRecord::AttributeAssignmentError
    end

    def multiparameter_assignment_errors_klass
      ::ActiveRecord::MultiparameterAssignmentErrors
    end
  end
end
