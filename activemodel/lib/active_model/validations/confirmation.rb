module ActiveModel

  # == Active Model Confirmation Validator
  module Validations
    class ConfirmationValidator < EachValidator
      def validate_each(record, attribute, value)
        confirmed = record.send(:"#{attribute}_confirmation")
        return if confirmed.nil? || value == confirmed
        record.errors.add(attribute, :confirmation, options)
      end

      def setup(klass)
        klass.send(:attr_accessor, *attributes.map { |attribute| :"#{attribute}_confirmation" })
      end
    end

    module HelperMethods
      # Encapsulates the pattern of wanting to validate a password or email 
      # address field with a confirmation. For example:
      #
      #   Model:
      #     class Person < ActiveRecord::Base
      #       validates_confirmation_of :user_name, :password
      #       validates_confirmation_of :email_address, 
      #                                 :message => "should match confirmation"
      #     end
      #
      #   View:
      #     <%= password_field "person", "password" %>
      #     <%= password_field "person", "password_confirmation" %>
      #
      # The added +password_confirmation+ attribute is virtual; it exists only 
      # as an in-memory attribute for validating the password. To achieve this,
      # the validation adds accessors to the model for the confirmation 
      # attribute.
      # 
      # NOTE: This check is performed only if +password_confirmation+ is not 
      # +nil+, and by default only on save. To require confirmation, make sure
      # to add a presence check for the confirmation attribute:
      #
      #   validates_presence_of :password_confirmation, :if => :password_changed?
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "doesn't match
      #   confirmation").
      # * <tt>:on</tt> - Specifies when this validation is active (default is
      #   <tt>:save</tt>, other options <tt>:create</tt>, <tt>:update</tt>).
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>:if => :allow_validation</tt>,
      #   or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>).  The
      #   method, proc or string should return or evaluate to a true or false 
      #   value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to 
      #   determine if the validation should not occur (e.g. 
      #   <tt>:unless => :skip_validation</tt>, or 
      #   <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a true or false value.
      def validates_confirmation_of(*attr_names)
        validates_with ConfirmationValidator, _merge_attributes(attr_names)
      end
    end
  end
end
