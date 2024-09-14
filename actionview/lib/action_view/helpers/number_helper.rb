# frozen_string_literal: true

require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/output_safety"
require "active_support/number_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View Number \Helpers
    #
    # Provides methods for converting numbers into formatted strings.
    # Methods are provided for phone numbers, currency, percentage,
    # precision, positional notation, file size, and pretty printing.
    #
    # Most methods expect a +number+ argument, and will return it
    # unchanged if can't be converted into a valid number.
    module NumberHelper
      # Raised when argument +number+ param given to the helpers is invalid and
      # the option +:raise+ is set to  +true+.
      class InvalidNumberError < StandardError
        attr_accessor :number
        def initialize(number)
          @number = number
        end
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_phone.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_to_phone("12x34")              # => "12x34"
      #   number_to_phone("12x34", raise: true) # => InvalidNumberError
      #
      def number_to_phone(number, options = {})
        return unless number
        options = options.symbolize_keys

        parse_float(number, true) if options.delete(:raise)
        ERB::Util.html_escape(ActiveSupport::NumberHelper.number_to_phone(number, options))
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_currency.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_to_currency("12x34")              # => "$12x34"
      #   number_to_currency("12x34", raise: true) # => InvalidNumberError
      #
      def number_to_currency(number, options = {})
        delegate_number_helper_method(:number_to_currency, number, options)
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_percentage.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_to_percentage("99x")              # => "99x%"
      #   number_to_percentage("99x", raise: true) # => InvalidNumberError
      #
      def number_to_percentage(number, options = {})
        delegate_number_helper_method(:number_to_percentage, number, options)
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_delimited.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_with_delimiter("12x34")              # => "12x34"
      #   number_with_delimiter("12x34", raise: true) # => InvalidNumberError
      #
      def number_with_delimiter(number, options = {})
        delegate_number_helper_method(:number_to_delimited, number, options)
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_rounded.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_with_precision("12x34")              # => "12x34"
      #   number_with_precision("12x34", raise: true) # => InvalidNumberError
      #
      def number_with_precision(number, options = {})
        delegate_number_helper_method(:number_to_rounded, number, options)
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_human_size.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_to_human_size("12x34")              # => "12x34"
      #   number_to_human_size("12x34", raise: true) # => InvalidNumberError
      #
      def number_to_human_size(number, options = {})
        delegate_number_helper_method(:number_to_human_size, number, options)
      end

      # Delegates to ActiveSupport::NumberHelper#number_to_human.
      #
      # Additionally, supports a +:raise+ option that will cause
      # InvalidNumberError to be raised if +number+ is not a valid number:
      #
      #   number_to_human("12x34")              # => "12x34"
      #   number_to_human("12x34", raise: true) # => InvalidNumberError
      #
      def number_to_human(number, options = {})
        delegate_number_helper_method(:number_to_human, number, options)
      end

      private
        def delegate_number_helper_method(method, number, options)
          return unless number
          options = escape_unsafe_options(options.symbolize_keys)

          wrap_with_output_safety_handling(number, options.delete(:raise)) {
            ActiveSupport::NumberHelper.public_send(method, number, options)
          }
        end

        def escape_unsafe_options(options)
          options[:format]          = ERB::Util.html_escape(options[:format]) if options[:format]
          options[:negative_format] = ERB::Util.html_escape(options[:negative_format]) if options[:negative_format]
          options[:separator]       = ERB::Util.html_escape(options[:separator]) if options[:separator]
          options[:delimiter]       = ERB::Util.html_escape(options[:delimiter]) if options[:delimiter]
          options[:unit]            = ERB::Util.html_escape(options[:unit]) if options[:unit] && !options[:unit].html_safe?
          options[:units]           = escape_units(options[:units]) if options[:units] && Hash === options[:units]
          options
        end

        def escape_units(units)
          units.transform_values do |v|
            ERB::Util.html_escape(v)
          end
        end

        def wrap_with_output_safety_handling(number, raise_on_invalid, &block)
          valid_float = valid_float?(number)
          raise InvalidNumberError, number if raise_on_invalid && !valid_float

          formatted_number = yield

          if valid_float || number.html_safe?
            formatted_number.html_safe
          else
            formatted_number
          end
        end

        def valid_float?(number)
          !parse_float(number, false).nil?
        end

        def parse_float(number, raise_error)
          result = Float(number, exception: false)
          raise InvalidNumberError, number if result.nil? && raise_error
          result
        end
    end
  end
end
