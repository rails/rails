# frozen_string_literal: true

module ActiveStorage
  module Validations
    class AttachmentContentTypeValidator < BaseValidator
      AVAILABLE_CHECKS = %i[in not with]

      def self.helper_method_name
        :validates_attachment_content_type
      end

      def check_validity!
        if options_blank?
          raise(
            ArgumentError,
            "You must pass at least one of #{AVAILABLE_CHECKS.join(", ")} to the validator"
          )
        end

        if options_redundant?
          raise(ArgumentError, "Cannot pass both :in and :not")
        end
      end

      private
        def error_key_for(check_name)
          { in: :inclusion, not: :exclusion, with: :inclusion }[check_name.to_sym]
        end

        def options_redundant?
          options.has_key?(:in) && options.has_key?(:not)
        end

        def passes_check?(blob, check_name, check_value)
          case check_name.to_sym
          when :in
            check_value.include?(blob.content_type)
          when :not
            !check_value.include?(blob.content_type)
          when :with
            # TODO: implement check_options_validity from AM::Validators::FormatValidator
            check_value.match?(blob.content_type)
          end
        end
    end

    module HelperMethods
      # Validates the content type of the ActiveStorage attachments. Happens by
      # default on save.
      #
      #   class Employee < ActiveRecord::Base
      #     has_one_attached :avatar
      #
      #     validates_attachment_content_type :avatar, in: %w[image/jpeg audio/ogg]
      #     validates_attachment_content_type :avatar, in: "image/jpeg"
      #   end
      #
      # Configuration options:
      # * <tt>in</tt> - a +Array+ or +String+ of allowable content types
      # * <tt>not</tt> - a +Array+ or +String+ of content types to exclude
      # * <tt>:message</tt> - A custom error message which overrides the
      #   default error message.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      def validates_attachment_content_type(*attributes)
        validates_with AttachmentContentTypeValidator, _merge_attributes(attributes)
      end
    end
  end
end
