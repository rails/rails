# frozen_string_literal: true

module ActiveModel
  module Validations
    class ConfirmationValidator < EachValidator # :nodoc:
      def initialize(options)
        super({ case_sensitive: true }.merge!(options))
        setup!(options[:class])
      end

      def validate_each(record, attribute, value)
        unless (confirmed = record.send("#{attribute}_confirmation")).nil?
          unless confirmation_value_equal?(record, attribute, value, confirmed)
            human_attribute_name = record.class.human_attribute_name(attribute)
            record.errors.add(:"#{attribute}_confirmation", :confirmation, options.except(:case_sensitive).merge!(attribute: human_attribute_name))
          end
        end
      end

      private
        def setup!(klass)
          klass.attr_reader(*attributes.map do |attribute|
            :"#{attribute}_confirmation" unless klass.method_defined?(:"#{attribute}_confirmation")
          end.compact)

          klass.attr_writer(*attributes.map do |attribute|
            :"#{attribute}_confirmation" unless klass.method_defined?(:"#{attribute}_confirmation=")
          end.compact)
        end

        def confirmation_value_equal?(record, attribute, value, confirmed)
          if !options[:case_sensitive] && value.is_a?(String)
            value.casecmp(confirmed) == 0
          else
            value == confirmed
          end
        end
    end

    module HelperMethods
      # Encapsulates the pattern of wanting to validate a password or email
      # address field with a confirmation.
      #
      #   Model:
      #     class Person < ActiveRecord::Base
      #       validates_confirmation_of :user_name, :password
      #       validates_confirmation_of :email_address,
      #                                 message: 'should match confirmation'
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
      # +nil+. To require confirmation, make sure to add a presence check for
      # the confirmation attribute:
      #
      #   validates_presence_of :password_confirmation, if: :password_changed?
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "doesn't match
      #   <tt>%{translated_attribute_name}</tt>").
      # * <tt>:case_sensitive</tt> - Looks for an exact match. Ignored by
      #   non-text columns (+true+ by default).
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      def validates_confirmation_of(*attr_names)
        validates_with ConfirmationValidator, _merge_attributes(attr_names)
      end
    end
  end
end
