module ActiveModel
  module Validations
    module ClassMethods
      ALL_RANGE_OPTIONS = [ :is, :within, :in, :minimum, :maximum ].freeze
    
      # Validates that the specified attribute matches the length restrictions supplied. Only one option can be used at a time:
      #
      #   class Person < ActiveRecord::Base
      #     validates_length_of :first_name, :maximum => 30
      #     validates_length_of :last_name, :maximum => 30, :message => "less than %d if you don't mind"
      #     validates_length_of :fax, :in => 7..32, :allow_nil => true
      #     validates_length_of :phone, :in => 7..32, :allow_blank => true
      #     validates_length_of :user_name, :within => 6..20, :too_long => "pick a shorter name", :too_short => "pick a longer name"
      #     validates_length_of :fav_bra_size, :minimum => 1, :too_short => "please enter at least %d character"
      #     validates_length_of :smurf_leader, :is => 4, :message => "papa is spelled with %d characters... don't play me."
      #   end
      #
      # Configuration options:
      # * <tt>:minimum</tt> - The minimum size of the attribute
      # * <tt>:maximum</tt> - The maximum size of the attribute
      # * <tt>:is</tt> - The exact size of the attribute
      # * <tt>:within</tt> - A range specifying the minimum and maximum size of the attribute
      # * <tt>:in</tt> - A synonym (or alias) for <tt>:within</tt>
      # * <tt>:allow_nil</tt> - Attribute may be +nil+; skip validation.
      # * <tt>:allow_blank</tt> - Attribute may be blank; skip validation.
      # * <tt>:too_long</tt> - The error message if the attribute goes over the maximum (default is: "is too long (maximum is %d characters)")
      # * <tt>:too_short</tt> - The error message if the attribute goes under the minimum (default is: "is too short (min is %d characters)")
      # * <tt>:wrong_length</tt> - The error message if using the <tt>:is</tt> method and the attribute is the wrong size (default is: "is the wrong length (should be %d characters)")
      # * <tt>:message</tt> - The error message to use for a <tt>:minimum</tt>, <tt>:maximum</tt>, or <tt>:is</tt> violation.  An alias of the appropriate <tt>:too_long</tt>/<tt>too_short</tt>/<tt>wrong_length</tt> message
      # * <tt>:on</tt> - Specifies when this validation is active (default is <tt>:save</tt>, other options <tt>:create</tt>, <tt>:update</tt>)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_length_of(*attrs)
        # Merge given options with defaults.
        options = {
          :too_long     => ActiveRecord::Errors.default_error_messages[:too_long],
          :too_short    => ActiveRecord::Errors.default_error_messages[:too_short],
          :wrong_length => ActiveRecord::Errors.default_error_messages[:wrong_length]
        }.merge(DEFAULT_VALIDATION_OPTIONS)
        options.update(attrs.extract_options!.symbolize_keys)

        # Ensure that one and only one range option is specified.
        range_options = ALL_RANGE_OPTIONS & options.keys
        case range_options.size
          when 0
            raise ArgumentError, 'Range unspecified.  Specify the :within, :maximum, :minimum, or :is option.'
          when 1
            # Valid number of options; do nothing.
          else
            raise ArgumentError, 'Too many range options specified.  Choose only one.'
        end

        # Get range option and value.
        option = range_options.first
        option_value = options[range_options.first]

        case option
          when :within, :in
            raise ArgumentError, ":#{option} must be a Range" unless option_value.is_a?(Range)

            too_short = options[:too_short] % option_value.begin
            too_long  = options[:too_long]  % option_value.end

            validates_each(attrs, options) do |record, attr, value|
              value = value.split(//) if value.kind_of?(String)
              if value.nil? or value.size < option_value.begin
                record.errors.add(attr, too_short)
              elsif value.size > option_value.end
                record.errors.add(attr, too_long)
              end
            end
          when :is, :minimum, :maximum
            raise ArgumentError, ":#{option} must be a nonnegative Integer" unless option_value.is_a?(Integer) and option_value >= 0

            # Declare different validations per option.
            validity_checks = { :is => "==", :minimum => ">=", :maximum => "<=" }
            message_options = { :is => :wrong_length, :minimum => :too_short, :maximum => :too_long }

            message = (options[:message] || options[message_options[option]]) % option_value

            validates_each(attrs, options) do |record, attr, value|
              value = value.split(//) if value.kind_of?(String)
              record.errors.add(attr, message) unless !value.nil? and value.size.method(validity_checks[option])[option_value]
            end
        end
      end

      alias_method :validates_size_of, :validates_length_of
    end
  end
end