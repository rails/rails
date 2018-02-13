# frozen_string_literal: true

module ActiveRecord
  module Validations
    class LengthValidator < ActiveModel::Validations::LengthValidator # :nodoc:
      def validate_each(record, attribute, association_or_value)
        if association_or_value.respond_to?(:loaded?) && association_or_value.loaded?
          association_or_value = association_or_value.target.reject(&:marked_for_destruction?)
        end
        super
      end
    end

    module ClassMethods
      # Validates that the specified attributes match the length restrictions supplied.
      # If the attribute is an association, records that are marked for destruction are not counted.
      #
      # See ActiveModel::Validations::HelperMethods.validates_length_of for more information.
      def validates_length_of(*attr_names)
        validates_with LengthValidator, _merge_attributes(attr_names)
      end

      alias_method :validates_size_of, :validates_length_of
    end
  end
end
