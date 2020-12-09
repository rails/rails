# frozen_string_literal: true

require "bigdecimal/util"

module ActiveModel
  module Validations
    class NumericalityValidator < EachValidator # :nodoc:
      CHECKS = { greater_than: :>, greater_than_or_equal_to: :>=,
                 equal_to: :==, less_than: :<, less_than_or_equal_to: :<=,
                 odd: :odd?, even: :even?, other_than: :!= }.freeze

      RESERVED_OPTIONS = CHECKS.keys + [:only_integer]

      INTEGER_REGEX = /\A[+-]?\d+\z/

      HEXADECIMAL_REGEX = /\A[+-]?0[xX]/

      def check_validity!
        keys = CHECKS.keys - [:odd, :even]
        options.slice(*keys).each do |option, value|
          unless value.is_a?(Numeric) || value.is_a?(Proc) || value.is_a?(Symbol)
            raise ArgumentError, ":#{option} must be a number, a symbol or a proc"
          end
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

        options.slice(*CHECKS.keys).each do |option, option_value|
          case option
          when :odd, :even
            unless value.to_i.public_send(CHECKS[option])
              record.errors.add(attr_name, option, **filtered_options(value))
            end
          else
            case option_value
            when Proc
              option_value = option_value.call(record)
            when Symbol
              option_value = record.send(option_value)
            end

            option_value = parse_as_number(option_value, precision, scale)

            unless value.public_send(CHECKS[option], option_value)
              record.errors.add(attr_name, option, **filtered_options(value).merge!(count: option_value))
            end
          end
        end
      end

    private
      def parse_as_number(raw_value, precision, scale)
        if raw_value.is_a?(Float)
          parse_float(raw_value, precision, scale)
        elsif raw_value.is_a?(Numeric)
          raw_value
        elsif is_integer?(raw_value)
          raw_value.to_i
        elsif !is_hexadecimal_literal?(raw_value)
          parse_float(Kernel.Float(raw_value), precision, scale)
        end
      end

      def parse_float(raw_value, precision, scale)
        (scale ? raw_value.truncate(scale) : raw_value).to_d(precision)
      end

      def is_number?(raw_value, precision, scale)
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
        case options[:only_integer]
        when Symbol
          record.send(options[:only_integer])
        when Proc
          options[:only_integer].call(record)
        else
          options[:only_integer]
        end
      end

      def read_attribute_for_validation(record, attr_name, value)
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
      # trying to convert it to a float with Kernel.Float (if <tt>only_integer</tt>
      # is +false+) or applying it to the regular expression <tt>/\A[\+\-]?\d+\z/</tt>
      # (if <tt>only_integer</tt> is set to +true+). Precision of Kernel.Float values
      # are guaranteed up to 15 digits.
      #
      #   class Person < ActiveRecord::Base
      #     validates_numericality_of :value, on: :create
      #   end
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "is not a number").
      # * <tt>:only_integer</tt> - Specifies whether the value has to be an
      #   integer, e.g. an integral value (default is +false+).
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+ (default is
      #   +false+). Notice that for Integer and Float columns empty strings are
      #   converted to +nil+.
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
      # * <tt>:other_than</tt> - Specifies the value must be other than the
      #   supplied value.
      # * <tt>:odd</tt> - Specifies the value must be an odd number.
      # * <tt>:even</tt> - Specifies the value must be an even number.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+ .
      # See <tt>ActiveModel::Validations#validates</tt> for more information
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
