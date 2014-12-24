module ActiveModel
  module Validations
    # == Active Model Unchanged Validator
    class UnchangedValidator < EachValidator #:nodoc:
      def validate_each(record, attr_name, value)#
        if !record.new_record? && record.send(:"#{attr_name}_changed?")
          record.errors.add(attr_name, :changed, options)
        end
      end
    end

    module HelperMethods
      # Validates that the specified attributes are unchanged (unless the record is new).
      # Happens by default on save.
      #
      #   class Person < ActiveRecord::Base
      #     validates_unchanged :first_name
      #   end
      #
      # The first_name attribute must be in the object and it must not have changed.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "must not change").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_unchanged(*attr_names)
        validates_with UnchangedValidator, _merge_attributes(attr_names)
      end
    end
  end
end
