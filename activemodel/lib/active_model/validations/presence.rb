
module ActiveModel

  module Validations
    class PresenceValidator < EachValidator # :nodoc:
      def validate_each(record, attr_name, value)
        record.errors.add(attr_name, :blank, options) if value.blank?
      end
    end

    module HelperMethods
      # Validates that the specified attributes are not blank (as defined by
      # Object#blank?). Happens by default on save.
      #
      #   class Person < ActiveRecord::Base
      #     validates_presence_of :first_name
      #   end
      #
      # The first_name attribute must be in the object and it cannot be blank.
      #
      # If you want to validate the presence of a boolean field (where the real
      # values are +true+ and +false+), you will want to use
      # <tt>validates_inclusion_of :field_name, in: [true, false]</tt>.
      #
      # This is due to the way Object#blank? handles boolean values:
      # <tt>false.blank? # => true</tt>.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "can't be blank").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+ and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_presence_of(*attr_names)
        validates_with PresenceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
