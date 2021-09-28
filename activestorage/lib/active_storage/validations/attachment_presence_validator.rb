# frozen_string_literal: true

module ActiveStorage
  module Validations
    class AttachmentPresenceValidator < BaseValidator
      AVAILABLE_CHECKS = []

      def self.helper_method_name
        :validates_attachment_presence
      end

      def validate_each(record, attribute, _value)
        return if record.send(attribute).attached?

        record.errors.add(attribute, :blank, **options)
      end

      private
      def error_key_for(check_name)
        ## Not Required
      end

      def options_redundant?
        ## Not Required
      end

      def passes_check?(blob, check_name, check_value)
        ## Not Required
      end
    end

    module HelperMethods
      # Validates the content type of the ActiveStorage attachments. Happens by
      # default on save.
      #
      #   class Employee < ActiveRecord::Base
      #     has_one_attached :avatar
      #
      #     validates_attachment_presence :avatar
      #   end
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message which overrides the
      #   default error message.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      def validates_attachment_presence(*attributes)
        validates_with AttachmentPresenceValidator, _merge_attributes(attributes)
      end
    end
  end
end

