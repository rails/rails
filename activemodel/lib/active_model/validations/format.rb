module ActiveModel
  module Validations
    module ClassMethods
      # Validates whether the value of the specified attribute is of the correct form by matching it against the regular expression
      # provided.
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :on => :create
      #   end
      #
      # Note: use <tt>\A</tt> and <tt>\Z</tt> to match the start and end of the string, <tt>^</tt> and <tt>$</tt> match the start/end of a line.
      #
      # A regular expression must be provided or else an exception will be raised.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "is invalid")
      # * <tt>:allow_nil</tt> - If set to +true+, skips this validation if the attribute is +nil+ (default is: +false+)
      # * <tt>:allow_blank</tt> - If set to +true+, skips this validation if the attribute is blank (default is: +false+)
      # * <tt>:with</tt> - The regular expression used to validate the format with (note: must be supplied!)
      # * <tt>:on</tt> - Specifies when this validation is active (default is <tt>:save</tt>, other options <tt>:create</tt>, <tt>:update</tt>)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_format_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:invalid], :on => :save, :with => nil }
        configuration.update(attr_names.extract_options!)

        raise(ArgumentError, "A regular expression must be supplied as the :with option of the configuration hash") unless configuration[:with].is_a?(Regexp)

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message]) unless value.to_s =~ configuration[:with]
        end
      end
    end
  end
end