module ActiveModel
  # == Active Model Format Validator
  module Validations
    class FormatValidator < EachValidator
      def validate_each(record, attribute, value)
        if options[:with]
          regexp = option_call(record, :with)
          record_error(record, attribute, :with, value) if value.to_s !~ regexp
        elsif options[:without]
          regexp = option_call(record, :without)
          record_error(record, attribute, :without, value) if value.to_s =~ regexp
        end
      end

      def check_validity!
        unless options.include?(:with) ^ options.include?(:without)  # ^ == xor, or "exclusive or"
          raise ArgumentError, "Either :with or :without must be supplied (but not both)"
        end

        check_options_validity(options, :with)
        check_options_validity(options, :without)
      end

      private

      def option_call(record, name)
        option = options[name]
        option.respond_to?(:call) ? option.call(record) : option
      end

      def record_error(record, attribute, name, value)
        record.errors.add(attribute, :invalid, options.except(name).merge!(:value => value))
      end

      def check_options_validity(options, name)
        option = options[name]
        if option && !option.is_a?(Regexp) && !option.respond_to?(:call)
          raise ArgumentError, "A regular expression or a proc or lambda must be supplied as :#{name}"
        end
      end
    end

    module HelperMethods
      # Validates whether the value of the specified attribute is of the correct form,
      # going by the regular expression provided. You can require that the attribute
      # matches the regular expression:
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :on => :create
      #   end
      #
      # Alternatively, you can require that the specified attribute does _not_ match
      # the regular expression:
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, :without => /NOSPAM/
      #   end
      #
      # You can also provide a proc or lambda which will determine the regular
      # expression that will be used to validate the attribute.
      #
      #   class Person < ActiveRecord::Base
      #     # Admin can have number as a first letter in their screen name
      #     validates_format_of :screen_name,
      #                         :with => lambda{ |person| person.admin? ? /\A[a-z0-9][a-z0-9_\-]*\Z/i : /\A[a-z][a-z0-9_\-]*\Z/i }
      #   end
      #
      # Note: use <tt>\A</tt> and <tt>\Z</tt> to match the start and end of the string,
      # <tt>^</tt> and <tt>$</tt> match the start/end of a line.
      #
      # You must pass either <tt>:with</tt> or <tt>:without</tt> as an option. In
      # addition, both must be a regular expression or a proc or lambda, or else an
      # exception will be raised.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "is invalid").
      # * <tt>:allow_nil</tt> - If set to true, skips this validation if the attribute
      #   is +nil+ (default is +false+).
      # * <tt>:allow_blank</tt> - If set to true, skips this validation if the
      #   attribute is blank (default is +false+).
      # * <tt>:with</tt> - Regular expression that if the attribute matches will
      #   result in a successful validation. This can be provided as a proc or lambda
      #   returning regular expression which will be called at runtime.
      # * <tt>:without</tt> - Regular expression that if the attribute does not match
      #   will result in a successful validation. This can be provided as a proc or
      #   lambda returning regular expression which will be called at runtime.
      # * <tt>:on</tt> - Specifies when this validation is active. Runs in all
      #   validation contexts by default (+nil+), other options are <tt>:create</tt>
      #   and <tt>:update</tt>.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the
      #   validation should occur (e.g. <tt>:if => :allow_validation</tt>, or
      #   <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>). The method, proc
      #   or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if
      #   the validation should not occur (e.g. <tt>:unless => :skip_validation</tt>,
      #   or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>). The method,
      #   proc or string should return or evaluate to a true or false value.
      # * <tt>:strict</tt> - Specifies whether validation should be strict. 
      #   See <tt>ActiveModel::Validation#validates!</tt> for more information.
      def validates_format_of(*attr_names)
        validates_with FormatValidator, _merge_attributes(attr_names)
      end
    end
  end
end
