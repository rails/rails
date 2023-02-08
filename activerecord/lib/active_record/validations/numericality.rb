# frozen_string_literal: true

module ActiveRecord
  module Validations
    class NumericalityValidator < ActiveModel::Validations::NumericalityValidator # :nodoc:
      def validate_each(record, attribute, value, precision: nil, scale: nil)
        precision = [column_precision_for(record, attribute) || Float::DIG, Float::DIG].min
        scale     = column_scale_for(record, attribute)
        super(record, attribute, value, precision: precision, scale: scale)
      end

      private
        def column_precision_for(record, attribute)
          record.class.type_for_attribute(attribute.to_s)&.precision
        end

        def column_scale_for(record, attribute)
          record.class.type_for_attribute(attribute.to_s)&.scale
        end
    end

    module ClassMethods
      # Validates whether the value of the specified attribute is numeric by
      # trying to convert it to a float with +Kernel.Float+ (if
      # <tt>only_integer</tt> is +false+) or applying it to the regular
      # expression <tt>/\A[\+\-]?\d+\z/</tt> (if <tt>only_integer</tt> is set to
      # +true+). +Kernel.Float+ precision defaults to the column's precision
      # value or 15.
      #
      # See ActiveModel::Validations::HelperMethods.validates_numericality_of for more information.
      def validates_numericality_of(*attr_names)
        validates_with NumericalityValidator, _merge_attributes(attr_names)
      end
    end
  end
end
