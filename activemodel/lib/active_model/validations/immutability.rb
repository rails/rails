module ActiveModel
  module Validations
    # == \Active \Model Immutability Validator
    class ImmutabilityValidator < EachValidator # :nodoc:
      def validate_each(record, attribute, value)
        record.errors.add(attribute, :immutability) if record.public_send("#{attribute}_changed?")
      end
    end

    module HelperMethods
      # Validates that the specified attributes are not changed during update process
      #
      #   class Person < ActiveRecord::Base
      #     validates_immutability_of :first_name
      #   end
      #
      # The first_name attribute must be in the object and the object must be persisted.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "can't be changed").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_immutability_of(*attr_names)
        validates_with ImmutabilityValidator, _merge_attributes(attr_names)
      end
    end
  end
end
