module ActiveRecord
  module Validations
    class LengthValidator < ActiveModel::Validations::LengthValidator # :nodoc:
      def validate_each(record, attribute, association_or_value)
        return unless should_validate?(record) || associations_are_dirty?(record)
        if association_or_value.respond_to?(:loaded?) && association_or_value.loaded?
          association_or_value = association_or_value.target.reject(&:marked_for_destruction?)
        end
        super
      end

      def associations_are_dirty?(record)
        attributes.any? do |attribute|
          value = record.read_attribute_for_validation(attribute)
          if value.respond_to?(:loaded?) && value.loaded?
            value.target.any?(&:marked_for_destruction?)
          else
            false
          end
        end
      end
    end

    module ClassMethods
      # See <tt>ActiveModel::Validation::LengthValidator</tt> for more information.
      def validates_length_of(*attr_names)
        validates_with LengthValidator, _merge_attributes(attr_names)
      end

      alias_method :validates_size_of, :validates_length_of
    end
  end
end
