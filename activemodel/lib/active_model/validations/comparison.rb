# frozen_string_literal: true

module ActiveModel
  module Validations
    class ComparisonValidator < EachValidator # :nodoc:
      include Comparability

      def check_validity!
        unless (options.keys & COMPARE_CHECKS.keys).any?
          raise ArgumentError, "Expected one of :greater_than, :greater_than_or_equal_to, "\
          ":equal_to, :less_than, :less_than_or_equal_to, nor :other_than supplied."
        end
      end

      def validate_each(record, attr_name, value)
        options.slice(*COMPARE_CHECKS.keys).each do |option, raw_option_value|
          if value.nil? || value.blank?
            return record.errors.add(attr_name, :blank, **error_options(value, error_value(record, raw_option_value)))
          end

          unless value.send(COMPARE_CHECKS[option], option_value(record, raw_option_value))
            record.errors.add(attr_name, option, **error_options(value, error_value(record, raw_option_value)))
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
      # * <tt>:message</tt> - A custom error message (default is: "failed comparison").
      # * <tt>:greater_than</tt> - Specifies the value must be greater than the
      #   supplied value.
      # * <tt>:greater_than_or_equal_to</tt> - Specifies the value must be
      #   greater than or equal the supplied value.
      # * <tt>:equal_to</tt> - Specifies the value must be equal to the supplied
      #   value.
      # * <tt>:less_than</tt> - Specifies the value must be less than the
      #   supplied value.
      # * <tt>:less_than_or_equal_to</tt> - Specifies the value must be less
      #   than or equal the supplied value.
      # * <tt>:other_than</tt> - Specifies the value must not be equal to the
      #   supplied value.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+ .
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      #
      # The validator requires at least one of the following checks be supplied.
      # Each will accept a proc, value, or a symbol which corresponds to a method:
      #
      # * <tt>:greater_than</tt>
      # * <tt>:greater_than_or_equal_to</tt>
      # * <tt>:equal_to</tt>
      # * <tt>:less_than</tt>
      # * <tt>:less_than_or_equal_to</tt>
      # * <tt>:other_than</tt>
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
