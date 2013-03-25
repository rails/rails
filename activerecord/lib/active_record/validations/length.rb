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
      # See <tt>ActiveModel::Validation::LengthValidator</tt> for more information.
      def validates_length_of(*attr_names)
        validates_with LengthValidator, _merge_attributes(attr_names)
      end

      alias_method :validates_size_of, :validates_length_of
    end
  end
end
