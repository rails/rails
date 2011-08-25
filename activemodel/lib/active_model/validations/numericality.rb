module ActiveModel

  # == Active Model Numericality Validator
  module Validations
    class NumericalityValidator < EachValidator
      CHECKS = { :greater_than => :>, :greater_than_or_equal_to => :>=,
                 :equal_to => :==, :less_than => :<, :less_than_or_equal_to => :<=,
                 :odd => :odd?, :even => :even? }.freeze

      RESERVED_OPTIONS = CHECKS.keys + [:only_integer]

      def check_validity!
        keys = CHECKS.keys - [:odd, :even]
        options.slice(*keys).each do |option, value|
          next if value.is_a?(Numeric) || value.is_a?(Proc) || value.is_a?(Symbol)
          raise ArgumentError, ":#{option} must be a number, a symbol or a proc"
        end
      end

      def validate_each(record, attr_name, value)
        before_type_cast = "#{attr_name}_before_type_cast"

        raw_value = record.send(before_type_cast) if record.respond_to?(before_type_cast.to_sym)
        raw_value ||= value

        return if options[:allow_nil] && raw_value.nil?

        unless value = parse_raw_value_as_a_number(raw_value)
          record.errors.add(attr_name, :not_a_number, filtered_options(raw_value))
          return
        end

        if options[:only_integer]
          unless value = parse_raw_value_as_an_integer(raw_value)
            record.errors.add(attr_name, :not_an_integer, filtered_options(raw_value))
            return
          end
        end

        options.slice(*CHECKS.keys).each do |option, option_value|
          case option
          when :odd, :even
            unless value.to_i.send(CHECKS[option])
              record.errors.add(attr_name, option, filtered_options(value))
            end
          else
            option_value = option_value.call(record) if option_value.is_a?(Proc)
            option_value = record.send(option_value) if option_value.is_a?(Symbol)

            unless value.send(CHECKS[option], option_value)
              record.errors.add(attr_name, option, filtered_options(value).merge(:count => option_value))
            end
          end
        end
      end

    protected

      def parse_raw_value_as_a_number(raw_value)
        case raw_value
        when /\A0[xX]/
          nil
        else
          begin
            Kernel.Float(raw_value)
          rescue ArgumentError, TypeError
            nil
          end
        end
      end

      def parse_raw_value_as_an_integer(raw_value)
        raw_value.to_i if raw_value.to_s =~ /\A[+-]?\d+\Z/
      end

      def filtered_options(value)
        options.except(*RESERVED_OPTIONS).merge!(:value => value)
      end
    end

    module HelperMethods
      # Validates whether the value of the specified attribute is numeric by trying to convert it to
      # a float with Kernel.Float (if <tt>only_integer</tt> is false) or applying it to the regular expression
      # <tt>/\A[\+\-]?\d+\Z/</tt> (if <tt>only_integer</tt> is set to true).
      #
      #   class Person < ActiveRecord::Base
      #     validates_numericality_of :value, :on => :create
      #   end
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "is not a number").
      # * <tt>:on</tt> - Specifies when this validation is active. Runs in all
      #   validation contexts by default (+nil+), other options are <tt>:create</tt>
      #   and <tt>:update</tt>.
      # * <tt>:only_integer</tt> - Specifies whether the value has to be an integer, e.g. an integral value (default is +false+).
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+ (default is +false+). Notice that for fixnum and float columns empty strings are converted to +nil+.
      # * <tt>:greater_than</tt> - Specifies the value must be greater than the supplied value.
      # * <tt>:greater_than_or_equal_to</tt> - Specifies the value must be greater than or equal the supplied value.
      # * <tt>:equal_to</tt> - Specifies the value must be equal to the supplied value.
      # * <tt>:less_than</tt> - Specifies the value must be less than the supplied value.
      # * <tt>:less_than_or_equal_to</tt> - Specifies the value must be less than or equal the supplied value.
      # * <tt>:odd</tt> - Specifies the value must be an odd number.
      # * <tt>:even</tt> - Specifies the value must be an even number.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>). The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:strict</tt> - Specifies whether validation should be strict. 
      #   See <tt>ActiveModel::Validation#validates!</tt> for more information
      #
      # The following checks can also be supplied with a proc or a symbol which corresponds to a method:
      # * <tt>:greater_than</tt>
      # * <tt>:greater_than_or_equal_to</tt>
      # * <tt>:equal_to</tt>
      # * <tt>:less_than</tt>
      # * <tt>:less_than_or_equal_to</tt>
      #
      #   class Person < ActiveRecord::Base
      #     validates_numericality_of :width, :less_than => Proc.new { |person| person.height }
      #     validates_numericality_of :width, :greater_than => :minimum_weight
      #   end
      #
      def validates_numericality_of(*attr_names)
        validates_with NumericalityValidator, _merge_attributes(attr_names)
      end
    end
  end
end
