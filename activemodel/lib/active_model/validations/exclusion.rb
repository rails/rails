# frozen_string_literal: true

require "active_model/validations/clusivity"

module ActiveModel
  module Validations
    class ExclusionValidator < EachValidator # :nodoc:
      include Clusivity

      def validate_each(record, attribute, value)
        if include?(record, value)
          record.errors.add(attribute, :exclusion, **options.except(:in, :within).merge!(value: value))
        end
      end
    end

    module HelperMethods
      # Validates that the value of the specified attribute is not in a
      # particular enumerable object.
      #
      #   class Person < ActiveRecord::Base
      #     validates_exclusion_of :username, in: %w( admin superuser ), message: "You don't belong here"
      #     validates_exclusion_of :age, in: 30..60, message: 'This site is only for under 30 and over 60'
      #     validates_exclusion_of :format, in: %w( mov avi ), message: "extension %{value} is not allowed"
      #     validates_exclusion_of :password, in: ->(person) { [person.username, person.first_name] },
      #                            message: 'should not be the same as your username or first name'
      #     validates_exclusion_of :karma, in: :reserved_karmas
      #   end
      #
      # Configuration options:
      # * <tt>:in</tt> - An enumerable object of items that the value shouldn't
      #   be part of. This can be supplied as a proc, lambda, or symbol which returns an
      #   enumerable. If the enumerable is a numerical, time, or datetime range the test
      #   is performed with <tt>Range#cover?</tt>, otherwise with <tt>include?</tt>. When
      #   using a proc or lambda the instance under validation is passed as an argument.
      # * <tt>:within</tt> - A synonym(or alias) for <tt>:in</tt>
      #   <tt>Range#cover?</tt>, otherwise with <tt>include?</tt>.
      # * <tt>:message</tt> - Specifies a custom error message (default is: "is
      #   reserved").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See ActiveModel::Validations::ClassMethods#validates for more information.
      def validates_exclusion_of(*attr_names)
        validates_with ExclusionValidator, _merge_attributes(attr_names)
      end
    end
  end
end
