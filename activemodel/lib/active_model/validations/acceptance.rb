module ActiveModel
  module Validations
    module ClassMethods
      # Encapsulates the pattern of wanting to validate the acceptance of a terms of service check box (or similar agreement). Example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_acceptance_of :terms_of_service
      #     validates_acceptance_of :eula, :message => "must be abided"
      #   end
      #
      # If the database column does not exist, the +terms_of_service+ attribute is entirely virtual. This check is
      # performed only if +terms_of_service+ is not +nil+ and by default on save.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "must be accepted").
      # * <tt>:on</tt> - Specifies when this validation is active (default is <tt>:save</tt>, other options <tt>:create</tt>, <tt>:update</tt>).
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+ (default is true).
      # * <tt>:accept</tt> - Specifies value that is considered accepted.  The default value is a string "1", which
      #   makes it easy to relate to an HTML checkbox. This should be set to +true+ if you are validating a database
      #   column, since the attribute is typecast from "1" to +true+ before validation.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_acceptance_of(*attr_names)
        configuration = { :allow_nil => true, :accept => "1" }
        configuration.update(attr_names.extract_options!)

        db_cols = begin
          column_names
        rescue Exception # To ignore both statement and connection errors
          []
        end

        names = attr_names.reject { |name| db_cols.include?(name.to_s) }
        attr_accessor(*names)

        validates_each(attr_names,configuration) do |record, attr_name, value|
          unless value == configuration[:accept]
            record.errors.add(attr_name, :accepted, :default => configuration[:message])
          end
        end
      end
    end
  end
end
