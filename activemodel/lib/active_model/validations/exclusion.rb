module ActiveModel
  module Validations
    module ClassMethods
      # Validates that the value of the specified attribute is not in a particular enumerable object.
      #
      #   class Person < ActiveRecord::Base
      #     validates_exclusion_of :username, :in => %w( admin superuser ), :message => "You don't belong here"
      #     validates_exclusion_of :age, :in => 30..60, :message => "This site is only for under 30 and over 60"
      #     validates_exclusion_of :format, :in => %w( mov avi ), :message => "extension %s is not allowed"
      #   end
      #
      # Configuration options:
      # * <tt>:in</tt> - An enumerable object of items that the value shouldn't be part of
      # * <tt>:message</tt> - Specifies a custom error message (default is: "is reserved")
      # * <tt>:allow_nil</tt> - If set to +true+, skips this validation if the attribute is +nil+ (default is: +false+)
      # * <tt>:allow_blank</tt> - If set to +true+, skips this validation if the attribute is blank (default is: +false+)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_exclusion_of(*attr_names)
        configuration = { :message => ActiveRecord::Errors.default_error_messages[:exclusion], :on => :save }
        configuration.update(attr_names.extract_options!)

        enum = configuration[:in] || configuration[:within]

        raise(ArgumentError, "An object with the method include? is required must be supplied as the :in option of the configuration hash") unless enum.respond_to?("include?")

        validates_each(attr_names, configuration) do |record, attr_name, value|
          record.errors.add(attr_name, configuration[:message] % value) if enum.include?(value)
        end
      end
    end
  end
end