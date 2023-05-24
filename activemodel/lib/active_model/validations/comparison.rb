# frozen_string_literal: true

require "active_model/validations/comparability"
require "active_model/validations/resolve_value"

module ActiveModel
  module Validations
    class ComparisonValidator < EachValidator # :nodoc:
      include Comparability
      include ResolveValue

      def check_validity!
        unless (options.keys & COMPARE_CHECKS.keys).any?
          raise ArgumentError, "Expected one of :greater_than, :greater_than_or_equal_to, "\
          ":equal_to, :less_than, :less_than_or_equal_to, or :other_than option to be supplied."
        end
      end

      def validate_each(record, attr_name, value)
        options.slice(*COMPARE_CHECKS.keys).each do |option, raw_option_value|
          option_value = resolve_value(record, raw_option_value)

          if value.nil? || value.blank?
            return record.errors.add(attr_name, :blank, **error_options(value, option_value))
          end

          unless value.public_send(COMPARE_CHECKS[option], option_value)
            record.errors.add(attr_name, option, **error_options(value, option_value))
          end
        rescue ArgumentError => e
          record.errors.add(attr_name, e.message)
        end
      end
    end

    module HelperMethods
      # Validates the value of a specified attribute fulfills all
      # defined comparisons with another value, proc, or attribute.
      #
      #   class Person < ActiveRecord::Base
      #     validates_comparison_of :value, greater_than: 'the sum of its parts'
      #   end
      #
      # Configuration options:
      # * +:message+ - A custom error message (default is: "failed comparison").
      # * +:greater_than+ - Specifies the value must be greater than the
      #   supplied value. The default error message for this option is _"must be
      #   greater than %{count}"_.
      # * +:greater_than_or_equal_to+ - Specifies the value must be
      #   greater than or equal to the supplied value. The default error message
      #   for this option is _"must be greater than or equal to %{count}"_.
      # * +:equal_to+ - Specifies the value must be equal to the supplied
      #   value. The default error message for this option is _"must be equal to
      #   %{count}"_.
      # * +:less_than+ - Specifies the value must be less than the
      #   supplied value. The default error message for this option is _"must be
      #   less than %{count}"_.
      # * +:less_than_or_equal_to+ - Specifies the value must be less
      #   than or equal to the supplied value. The default error message for
      #   this option is _"must be less than or equal to %{count}"_.
      # * +:other_than+ - Specifies the value must not be equal to the
      #   supplied value. The default error message for this option is _"must be
      #   other than %{count}"_.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+ .
      # See ActiveModel::Validations::ClassMethods#validates for more information.
      #
      # The validator requires at least one of the following checks to be supplied.
      # Each will accept a proc, value, or a symbol which corresponds to a method:
      #
      # * +:greater_than+
      # * +:greater_than_or_equal_to+
      # * +:equal_to+
      # * +:less_than+
      # * +:less_than_or_equal_to+
      # * +:other_than+
      #
      # For example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_comparison_of :birth_date, less_than_or_equal_to: -> { Date.today }
      #     validates_comparison_of :preferred_name, other_than: :given_name, allow_nil: true
      #   end
      def validates_comparison_of(*attr_names)
        validates_with ComparisonValidator, _merge_attributes(attr_names)
      end
    end
  end
end
