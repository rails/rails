module ActiveModel

  # == Active Model Length Validator
  module Validations
    class LengthValidator < EachValidator
      MESSAGES  = { :is => :wrong_length, :minimum => :too_short, :maximum => :too_long }.freeze
      CHECKS    = { :is => :==, :minimum => :>=, :maximum => :<= }.freeze

      DEFAULT_TOKENIZER = lambda { |value| value.split(//) }
      RESERVED_OPTIONS  = [:minimum, :maximum, :within, :is, :tokenizer, :too_short, :too_long]

      def initialize(options)
        if range = (options.delete(:in) || options.delete(:within))
          raise ArgumentError, ":in and :within must be a Range" unless range.is_a?(Range)
          options[:minimum], options[:maximum] = range.begin, range.end
          options[:maximum] -= 1 if range.exclude_end?
        end

        super
      end

      def check_validity!
        keys = CHECKS.keys & options.keys

        if keys.empty?
          raise ArgumentError, 'Range unspecified. Specify the :within, :maximum, :minimum, or :is option.'
        end

        keys.each do |key|
          value = options[key]

          unless value.is_a?(Integer) && value >= 0
            raise ArgumentError, ":#{key} must be a nonnegative Integer"
          end
        end
      end

      def validate_each(record, attribute, value)
        value = (options[:tokenizer] || DEFAULT_TOKENIZER).call(value) if value.kind_of?(String)

        CHECKS.each do |key, validity_check|
          next unless check_value = options[key]

          value ||= [] if key == :maximum

          value_length = value.respond_to?(:length) ? value.length : value.to_s.length
          next if value_length.send(validity_check, check_value)

          errors_options = options.except(*RESERVED_OPTIONS)
          errors_options[:count] = check_value

          default_message = options[MESSAGES[key]]
          errors_options[:message] ||= default_message if default_message

          record.errors.add(attribute, MESSAGES[key], errors_options)
        end
      end
    end

    module HelperMethods

      # Validates that the specified attribute matches the length restrictions supplied. Only one option can be used at a time:
      #
      #   class Person < ActiveRecord::Base
      #     validates_length_of :first_name, :maximum => 30
      #     validates_length_of :last_name, :maximum => 30, :message => "less than 30 if you don't mind"
      #     validates_length_of :fax, :in => 7..32, :allow_nil => true
      #     validates_length_of :phone, :in => 7..32, :allow_blank => true
      #     validates_length_of :user_name, :within => 6..20, :too_long => "pick a shorter name", :too_short => "pick a longer name"
      #     validates_length_of :zip_code, :minimum => 5, :too_short => "please enter at least 5 characters"
      #     validates_length_of :smurf_leader, :is => 4, :message => "papa is spelled with 4 characters... don't play me."
      #     validates_length_of :essay, :minimum => 100, :too_short => "Your essay must be at least 100 words.", :tokenizer => lambda { |str| str.scan(/\w+/) }
      #   end
      #
      # Configuration options:
      # * <tt>:minimum</tt> - The minimum size of the attribute.
      # * <tt>:maximum</tt> - The maximum size of the attribute.
      # * <tt>:is</tt> - The exact size of the attribute.
      # * <tt>:within</tt> - A range specifying the minimum and maximum size of the attribute.
      # * <tt>:in</tt> - A synonym(or alias) for <tt>:within</tt>.
      # * <tt>:allow_nil</tt> - Attribute may be +nil+; skip validation.
      # * <tt>:allow_blank</tt> - Attribute may be blank; skip validation.
      # * <tt>:too_long</tt> - The error message if the attribute goes over the maximum (default is: "is too long (maximum is %{count} characters)").
      # * <tt>:too_short</tt> - The error message if the attribute goes under the minimum (default is: "is too short (min is %{count} characters)").
      # * <tt>:wrong_length</tt> - The error message if using the <tt>:is</tt> method and the attribute is the wrong size (default is: "is the wrong length (should be %{count} characters)").
      # * <tt>:message</tt> - The error message to use for a <tt>:minimum</tt>, <tt>:maximum</tt>, or <tt>:is</tt> violation.  An alias of the appropriate <tt>too_long</tt>/<tt>too_short</tt>/<tt>wrong_length</tt> message.
      # * <tt>:on</tt> - Specifies when this validation is active. Runs in all
      #   validation contexts by default (+nil+), other options are <tt>:create</tt>
      #   and <tt>:update</tt>.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:tokenizer</tt> - Specifies how to split up the attribute string. (e.g. <tt>:tokenizer => lambda {|str| str.scan(/\w+/)}</tt> to
      #   count words as in above example.)
      #   Defaults to <tt>lambda{ |value| value.split(//) }</tt> which counts individual characters.
      def validates_length_of(*attr_names)
        validates_with LengthValidator, _merge_attributes(attr_names)
      end

      alias_method :validates_size_of, :validates_length_of
    end
  end
end
