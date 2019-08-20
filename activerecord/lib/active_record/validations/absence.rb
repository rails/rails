# frozen_string_literal: true

module ActiveRecord
  module Validations
    class AbsenceValidator < ActiveModel::Validations::AbsenceValidator # :nodoc:
      def validate_each(record, attribute, association_or_value)
        if record.class._reflect_on_association(attribute)
          association_or_value = Array.wrap(association_or_value).reject(&:marked_for_destruction?)
        end
        super
      end
    end

    module ClassMethods
      # Validates that the specified attributes are not present (as defined by
      # Object#present?). If the attribute is an association, the associated object
      # is considered absent if it was marked for destruction.
      #
      # See ActiveModel::Validations::HelperMethods.validates_absence_of for more information.
      def validates_absence_of(*attr_names)
        validates_with AbsenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
