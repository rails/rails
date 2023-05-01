# frozen_string_literal: true

module ActiveRecord
  module Validations
    class NumericalityValidator < ActiveModel::Validations::NumericalityValidator # :nodoc:
      def validate_each(record, attribute, value, precision: nil, scale: nil)
        precision = [column_precision_for(record, attribute) || Float::DIG, Float::DIG].min
        scale     = column_scale_for(record, attribute)

        options.slice(*RESERVED_OPTIONS).each do |option, option_value|
          if RANGE_CHECKS.include?(option) && option_value == :limit
            option_value = parse_column_limit_as_range(record, attribute)
            next unless option_value
            unless value.public_send(RANGE_CHECKS[option], option_value)
              record.errors.add(attribute, option, **filtered_options(value).merge!(count: option_value))
            end
          end
        end

        super(record, attribute, value, precision: precision, scale: scale)
      end

      private
        def column_precision_for(record, attribute)
          record.class.type_for_attribute(attribute.to_s)&.precision
        end

        def column_scale_for(record, attribute)
          record.class.type_for_attribute(attribute.to_s)&.scale
        end

        def parse_column_limit_as_range(record, attribute)
          column = record.class.columns_hash[attribute.to_s]

          unless column
            raise ArgumentError, "cannot validate :limit for a virtual attribute"
          end

          limit_in_bytes = column.sql_type_metadata.limit
          return nil unless limit_in_bytes

          upper_limit = 2**(limit_in_bytes * 8 - 1) - 1
          (..upper_limit)
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
