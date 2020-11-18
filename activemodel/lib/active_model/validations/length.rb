# frozen_string_literal: true

module ActiveModel
  module Validations
    class LengthValidator < EachValidator # :nodoc:
      MESSAGES  = { is: :wrong_length, minimum: :too_short, maximum: :too_long }.freeze
      CHECKS    = { is: :==, minimum: :>=, maximum: :<= }.freeze

      RESERVED_OPTIONS = [:minimum, :maximum, :within, :is, :too_short, :too_long]

      def initialize(options)
        if range = (options.delete(:in) || options.delete(:within))
          raise ArgumentError, ":in and :within must be a Range" unless range.is_a?(Range)
          options[:minimum], options[:maximum] = range.min, range.max
        end

        if options[:allow_blank] == false && options[:minimum].nil? && options[:is].nil?
          options[:minimum] = 1
        end

        super
      end

      def check_validity!
        keys = CHECKS.keys & options.keys

        if keys.empty?
          raise ArgumentError, "Range unspecified. Specify the :in, :within, :maximum, :minimum, or :is option."
        end

        keys.each do |key|
          value = options[key]

          unless (value.is_a?(Integer) && value >= 0) || value == Float::INFINITY || value.is_a?(Symbol) || value.is_a?(Proc)
            raise ArgumentError, ":#{key} must be a non-negative Integer, Infinity, Symbol, or Proc"
          end
        end
      end

      def validate_each(record, attribute, value)
        value_length = value.respond_to?(:length) ? value.length : value.to_s.length
        errors_options = options.except(*RESERVED_OPTIONS)

        CHECKS.each do |key, validity_check|
          next unless check_value = options[key]

          if !value.nil? || skip_nil_check?(key)
            case check_value
            when Proc
              check_value = check_value.call(record)
            when Symbol
              check_value = record.send(check_value)
            end
            next if value_length.public_send(validity_check, check_value)
          end

          errors_options[:count] = check_value

          default_message = options[MESSAGES[key]]
          errors_options[:message] ||= default_message if default_message

          record.errors.add(attribute, MESSAGES[key], **errors_options)
        end
      end

      private
        def skip_nil_check?(key)
          %i(maximum minimum).include?(key) && options[key] != 0 && options[:allow_nil].nil? && options[:allow_blank].nil?
        end
    end

    module HelperMethods
      # Validates that the specified attributes match the length restrictions
      # supplied. Only one constraint option can be used at a time apart from
      # +:minimum+ and +:maximum+ that can be combined together:
      #
      #   class Person < ActiveRecord::Base
      #     validates_length_of :first_name, maximum: 30
      #     validates_length_of :last_name, maximum: 30, message: "less than 30 if you don't mind"
      #     validates_length_of :fax, in: 7..32, allow_nil: true
      #     validates_length_of :phone, in: 7..32, allow_blank: true
      #     validates_length_of :user_name, within: 6..20, too_long: 'pick a shorter name', too_short: 'pick a longer name'
      #     validates_length_of :zip_code, minimum: 5, too_short: 'please enter at least 5 characters'
      #     validates_length_of :smurf_leader, is: 4, message: "papa is spelled with 4 characters... don't play me."
      #     validates_length_of :words_in_essay, minimum: 100, too_short: 'Your essay must be at least 100 words.'
      #
      #     private
      #
      #     def words_in_essay
      #       essay.scan(/\w+/)
      #     end
      #   end
      #
      # Constraint options:
      #
      # * <tt>:minimum</tt> - The minimum size of the attribute.
      # * <tt>:maximum</tt> - The maximum size of the attribute. Allows +nil+ by
      #   default if not used with +:minimum+.
      # * <tt>:is</tt> - The exact size of the attribute.
      # * <tt>:within</tt> - A range specifying the minimum and maximum size of
      #   the attribute.
      # * <tt>:in</tt> - A synonym (or alias) for <tt>:within</tt>.
      #
      # Other options:
      #
      # * <tt>:allow_nil</tt> - Attribute may be +nil+; skip validation.
      # * <tt>:allow_blank</tt> - Attribute may be blank; skip validation.
      # * <tt>:too_long</tt> - The error message if the attribute goes over the
      #   maximum (default is: "is too long (maximum is %{count} characters)").
      # * <tt>:too_short</tt> - The error message if the attribute goes under the
      #   minimum (default is: "is too short (minimum is %{count} characters)").
      # * <tt>:wrong_length</tt> - The error message if using the <tt>:is</tt>
      #   method and the attribute is the wrong size (default is: "is the wrong
      #   length (should be %{count} characters)").
      # * <tt>:message</tt> - The error message to use for a <tt>:minimum</tt>,
      #   <tt>:maximum</tt>, or <tt>:is</tt> violation. An alias of the appropriate
      #   <tt>too_long</tt>/<tt>too_short</tt>/<tt>wrong_length</tt> message.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+ and +:strict+.
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      def validates_length_of(*attr_names)
        validates_with LengthValidator, _merge_attributes(attr_names)
      end

      alias_method :validates_size_of, :validates_length_of
    end
  end
end
