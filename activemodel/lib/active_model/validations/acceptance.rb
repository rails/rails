module ActiveModel

  # == Active Model Acceptance Validator
  module Validations
    class AcceptanceValidator < EachValidator
      def initialize(options)
        super(options.reverse_merge(:allow_nil => true, :accept => "1"))
      end

      def validate_each(record, attribute, value)
        unless value == options[:accept]
          record.errors.add(attribute, :accepted, options.except(:accept, :allow_nil))
        end
      end

      def setup(klass)
        # Note: instance_methods.map(&:to_s) is important for 1.9 compatibility
        # as instance_methods returns symbols unlike 1.8 which returns strings.
        attr_readers = attributes.reject { |name| klass.attribute_method?(name) }
        attr_writers = attributes.reject { |name| klass.attribute_method?("#{name}=") }
        klass.send(:attr_reader, *attr_readers)
        klass.send(:attr_writer, *attr_writers)
      end
    end

    module HelperMethods
      # Encapsulates the pattern of wanting to validate the acceptance of a 
      # terms of service check box (or similar agreement). Example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_acceptance_of :terms_of_service
      #     validates_acceptance_of :eula, :message => "must be abided"
      #   end
      #
      # If the database column does not exist, the +terms_of_service+ attribute 
      # is entirely virtual. This check is performed only if +terms_of_service+
      # is not +nil+ and by default on save.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "must be 
      #   accepted").
      # * <tt>:on</tt> - Specifies when this validation is active (default is
      #   <tt>:save</tt>, other options are <tt>:create</tt> and 
      #   <tt>:update</tt>).
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+ (default
      #   is true).
      # * <tt>:accept</tt> - Specifies value that is considered accepted. 
      #   The default value is a string "1", which makes it easy to relate to
      #   an HTML checkbox. This should be set to +true+ if you are validating 
      #   a database column, since the attribute is typecast from "1" to +true+
      #   before validation.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>:if => :allow_validation</tt>,
      #   or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false 
      #   value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to 
      #   determine if the validation should not occur (for example, 
      #   <tt>:unless => :skip_validation</tt>, or 
      #   <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>).
      #   The method, proc or string should return or evaluate to a true or 
      #   false value.
      def validates_acceptance_of(*attr_names)
        validates_with AcceptanceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
