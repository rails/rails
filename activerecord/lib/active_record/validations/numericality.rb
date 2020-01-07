# frozen_string_literal: true

module ActiveRecord
  module Validations
    class NumericalityValidator < ActiveModel::Validations::NumericalityValidator # :nodoc:
      def initialize(options)
        super
        @klass = options[:class]
      end

      def validate_each(record, attribute, value, precision: nil)
        precision = column_precision_for(attribute) || Float::DIG
        super
      end

      private
        def column_precision_for(attribute)
          if @klass < ActiveRecord::Base
            @klass.type_for_attribute(attribute.to_s)&.precision
          end
        end
    end

    module ClassMethods
      # Validates whether the value of the specified attribute is numeric by
      # trying to convert it to a float with Kernel.Float (if <tt>only_integer</tt>
      # is +false+) or applying it to the regular expression <tt>/\A[\+\-]?\d+\z/</tt>
      # (if <tt>only_integer</tt> is set to +true+). Kernel.Float precision
      # defaults to the column's precision value or 15.
      #
      # See ActiveModel::Validations::HelperMethods.validates_numericality_of for more information.
      def validates_numericality_of(*attr_names)
        validates_with NumericalityValidator, _merge_attributes(attr_names)
      end
    end
  end
end
