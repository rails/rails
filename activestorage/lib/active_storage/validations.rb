# frozen_string_literal: true

require "active_model"
require "active_support/concern"
require "active_support/core_ext/array/wrap"
require "active_storage/validations/base_validator"
require "active_storage/validations/attachment_byte_size_validator"
require "active_storage/validations/attachment_content_type_validator"
require "active_storage/validations/attachment_presence_validator"

module ActiveStorage
  # Provides the class-level DSL for declaring ActiveStorage validations
  module Validations
    extend ActiveSupport::Concern

    included do
      extend  HelperMethods
      include HelperMethods
    end

    module ClassMethods
      # A helper method to run various Active Storage attachment validators.
      #
      # Effectively the same as the <tt>ActiveModel::Validations#validates</tt>
      # method but more readable since it does not require the +attachment_+
      # prefix for its keys.
      #
      #   validates_attachment :avatar, size: { in: 2..4.megabytes }
      #   validates_attachment :avatar, content_type: { in: "image/jpeg" }
      #
      # Like the <tt>ActiveModel::Validations#validates</tt>, it also
      # supports shortcut options which can handle ranges, arrays, and strings.
      #
      #   validates_attachment :avatar, size: 2..4.megabytes
      #   validates_attachment :avatar, content_type: "image/jpeg"
      #
      # When using shortcut form, ranges and arrays are passed to the
      # validator as if they were specified with the +:in+ option, while other
      # types including regular expressions and strings are passed as if they
      # were specified using +:with+.
      def validates_attachment(*attributes)
        options = attributes.extract_options!.dup

        ActiveStorage::Validations.constants.each do |constant|
          if constant.to_s =~ /\AAttachment(.+)Validator\z/
            validator_kind = $1.underscore.to_sym

            if options.has_key?(validator_kind)
              validator_options = options.delete(validator_kind)
              validator_options = parse_shortcut_options(validator_options)

              conditional_options = options.slice(:if, :unless)

              Array.wrap(validator_options).each do |local_options|
                method_name = ActiveStorage::Validations.const_get(constant.to_s).helper_method_name
                send(method_name, attributes, local_options.merge(conditional_options))
              end
            end
          end
        end
      end

      private
        def parse_shortcut_options(options)
          _parse_validates_options(options)
        end
    end
  end
end
