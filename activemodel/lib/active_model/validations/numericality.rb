# frozen_string_literal: true

require "active_model/validations/comparability"
require "active_model/validations/resolve_value"
require "bigdecimal/util"

module ActiveModel
  module Validations
    class NumericalityValidator < EachValidator # :nodoc:
      include Clusivity
      include Comparability
      include ResolveValue

      CLUSIVITY_CHECKS = %i[in within]
      NUMBER_CHECKS = { odd: :odd?, even: :even? }

      RESERVED_OPTIONS = COMPARE_CHECKS.keys + NUMBER_CHECKS.keys + CLUSIVITY_CHECKS + [:only_integer, :only_numeric]

      INTEGER_REGEX = /\A[+-]?\d+\z/

      HEXADECIMAL_REGEX = /\A[+-]?0[xX]/

      def check_validity!
        options.slice(*COMPARE_CHECKS.keys).each do |option, value|
          unless value.is_a?(Numeric) || value.is_a?(Proc) || value.is_a?(Symbol)
            raise ArgumentError, ":#{option} must be a number, a symbol or a proc"
          end
        end

        if CLUSIVITY_CHECKS.any? { |check| options.key?(check) }
          super
        end
      end

      def validate_each(record, attr_name, value, precision: Float::DIG, scale: nil)
        unless is_number?(value, precision, scale)
          record.errors.add(attr_name, :not_a_number, **filtered_options(value))
          return
        end

        if allow_only_integer?(record) && !is_integer?(value)
          record.errors.add(attr_name, :not_an_integer, **filtered_options(value))
          return
        end

        value = parse_as_number(value, precision, scale)

        options.slice(*RESERVED_OPTIONS).each do |option, option_value|
          if NUMBER_CHECKS.include?(option)
            unless value.to_i.public_send(NUMBER_CHECKS[option])
              record.errors.add(attr_name, option, **filtered_options(value))
            end
          elsif CLUSIVITY_CHECKS.include?(option)
            unless include?(record, value)
              record.errors.add(attr_name, option, **filtered_options(value).merge!(count: option_value))
            end
          elsif COMPARE_CHECKS.include?(option)
            option_value = option_as_number(record, option_value, precision, scale)
            unless value.public_send(COMPARE_CHECKS[option], option_value)
              record.errors.add(attr_name, option, **filtered_options(value).merge!(count: option_value))
            end
          end
        end
      end

    private
      def option_as_number(record, option_value, precision, scale)
        parse_as_number(resolve_value(record, option_value), precision, scale)
      end

      def parse_as_number(raw_value, precision, scale)
        if raw_value.is_a?(Float)
          parse_float(raw_value, precision, scale)
        elsif raw_value.is_a?(BigDecimal)
          round(raw_value, scale)
        elsif raw_value.is_a?(Numeric)
          raw_value
        elsif is_integer?(raw_value)
          raw_value.to_i
        elsif !is_hexadecimal_literal?(raw_value)
          parse_float(Kernel.Float(raw_value), precision, scale)
        end
      end

      def parse_float(raw_value, precision, scale)
        round(raw_value, scale).to_d(precision)
      end

      def round(raw_value, scale)
        scale ? raw_value.round(scale) : raw_value
      end

      def is_number?(raw_value, precision, scale)
        if options[:only_numeric] && !raw_value.is_a?(Numeric)
          return false
        end

        !parse_as_number(raw_value, precision, scale).nil?
      rescue ArgumentError, TypeError
        false
      end

      def is_integer?(raw_value)
        INTEGER_REGEX.match?(raw_value.to_s)
      end

      def is_hexadecimal_literal?(raw_value)
        HEXADECIMAL_REGEX.match?(raw_value.to_s)
      end

      def filtered_options(value)
        filtered = options.except(*RESERVED_OPTIONS)
        filtered[:value] = value
        filtered
      end

      def allow_only_integer?(record)
        resolve_value(record, options[:only_integer])
      end

      def prepare_value_for_validation(value, record, attr_name)
        return value if record_attribute_changed_in_place?(record, attr_name)

        came_from_user = :"#{attr_name}_came_from_user?"

        if record.respond_to?(came_from_user)
          if record.public_send(came_from_user)
            raw_value = record.public_send(:"#{attr_name}_before_type_cast")
          elsif record.respond_to?(:read_attribute)
            raw_value = record.read_attribute(attr_name)
          end
        else
          before_type_cast = :"#{attr_name}_before_type_cast"
          if record.respond_to?(before_type_cast)
            raw_value = record.public_send(before_type_cast)
          end
        end

        raw_value || value
      end

      def record_attribute_changed_in_place?(record, attr_name)
        record.respond_to?(:attribute_changed_in_place?) &&
          record.attribute_changed_in_place?(attr_name.to_s)
      end
    end

    module HelperMethods
      # Validates whether the value of the specified attribute is numeric by
      # trying to convert it to a float with +Kernel.Float+ (if
      # <tt>only_integer</tt> is +false+) or applying it to the regular
      # expression <tt>/\A[\+\-]?\d+\z/</tt> (if <tt>only_integer</tt> is set to
      # +true+). Precision of +Kernel.Float+ values are guaranteed up to 15
      # digits.
      #
      #   class Person < ActiveRecord::Base
      #     validates_numericality_of :value, on: :create
      #   end
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "is not a number").
      # * <tt>:only_integer</tt> - Specifies whether the value has to be an
      #   integer (default is +false+).
      # * <tt>:only_numeric</tt> - Specifies whether the value has to be an
      #   instance of Numeric (default is +false+). The default behavior is to
      #   attempt parsing the value if it is a String.
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+ (default is
      #   +false+). Notice that for Integer and Float columns empty strings are
      #   converted to +nil+.
      # * <tt>:greater_than</tt> - Specifies the value must be greater than the
      #   supplied value. The default error message for this option is _"must be
      #   greater than %{count}"_.
      # * <tt>:greater_than_or_equal_to</tt> - Specifies the value must be
      #   greater than or equal the supplied value. The default error message
      #   for this option is _"must be greater than or equal to %{count}"_.
      # * <tt>:equal_to</tt> - Specifies the value must be equal to the supplied
      #   value. The default error message for this option is _"must be equal to
      #   %{count}"_.
      # * <tt>:less_than</tt> - Specifies the value must be less than the
      #   supplied value. The default error message for this option is _"must be
      #   less than %{count}"_.
      # * <tt>:less_than_or_equal_to</tt> - Specifies the value must be less
      #   than or equal the supplied value. The default error message for this
      #   option is _"must be less than or equal to %{count}"_.
      # * <tt>:other_than</tt> - Specifies the value must be other than the
      #   supplied value. The default error message for this option is _"must be
      #   other than %{count}"_.
      # * <tt>:odd</tt> - Specifies the value must be an odd number. The default
      #   error message for this option is _"must be odd"_.
      # * <tt>:even</tt> - Specifies the value must be an even number. The
      #   default error message for this option is _"must be even"_.
      # * <tt>:in</tt> - Check that the value is within a range. The default
      #   error message for this option is _"must be in %{count}"_.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+ .
      # See ActiveModel::Validations::ClassMethods#validates for more information.
      #
      # The following checks can also be supplied with a proc or a symbol which
      # corresponds to a method:
      #
      # * <tt>:greater_than</tt>
      # * <tt>:greater_than_or_equal_to</tt>
      # * <tt>:equal_to</tt>
      # * <tt>:less_than</tt>
      # * <tt>:less_than_or_equal_to</tt>
      # * <tt>:only_integer</tt>
      # * <tt>:other_than</tt>
      #
      # For example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_numericality_of :width, less_than: ->(person) { person.height }
      #     validates_numericality_of :width, greater_than: :minimum_weight
      #   end
      def validates_numericality_of(*attr_names)
        validates_with NumericalityValidator, _merge_attributes(attr_names)
      end
    end
  end
end
