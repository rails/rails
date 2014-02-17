require "active_model/validations/clusivity"

module ActiveModel

  module Validations
    class InclusionValidator < EachValidator # :nodoc:
      include Clusivity

      def validate_each(record, attribute, value)
        unless include?(record, value)
          record.errors.add(attribute, :inclusion, options.except(:in, :within).merge!(value: value))
        end
      end
    end

    module HelperMethods
      # Validates whether the value of the specified attribute is available in a
      # particular enumerable object.
      #
      #   class Person < ActiveRecord::Base
      #     validates_inclusion_of :gender, in: %w( m f )
      #     validates_inclusion_of :age, in: 0..99
      #     validates_inclusion_of :format, in: %w( jpg gif png ), message: "extension %{value} is not included in the list"
      #     validates_inclusion_of :states, in: ->(person) { STATES[person.country] }
      #     validates_inclusion_of :karma, in: :available_karmas
      #   end
      #
      # Configuration options:
      # * <tt>:in</tt> - An enumerable object of available items. This can be
      #   supplied as a proc, lambda or symbol which returns an enumerable. If the
      #   enumerable is a numerical range the test is performed with <tt>Range#cover?</tt>,
      #   otherwise with <tt>include?</tt>. When using a proc or lambda the instance
      #   under validation is passed as an argument.
      # * <tt>:within</tt> - A synonym(or alias) for <tt>:in</tt>
      # * <tt>:message</tt> - Specifies a custom error message (default is: "is
      #   not included in the list").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_inclusion_of(*attr_names)
        validates_with InclusionValidator, _merge_attributes(attr_names)
      end
    end
  end
end
