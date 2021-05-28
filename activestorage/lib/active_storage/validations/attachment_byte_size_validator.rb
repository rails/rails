# frozen_string_literal: true

module ActiveStorage
  module Validations
    class AttachmentByteSizeValidator < BaseValidator
      AVAILABLE_CHECKS = %i[minimum maximum in]

      def self.helper_method_name
        :validates_attachment_byte_size
      end

      def initialize(options = {})
        super
        error_options.merge!(
          minimum: to_human_size(minimum),
          maximum: to_human_size(maximum)
        )
      end

      def check_validity!
        if options_blank?
          raise(
            ArgumentError,
            "You must pass either :minimum, :maximum, or :in to the validator"
          )
        end

        if options_redundant?
          raise(
            ArgumentError,
            "Cannot pass :minimum or :maximum if already passing :in"
          )
        end
      end

      private
        def error_key_for(check_name)
          check_name == :in ? :in_between : check_name
        end

        def options_redundant?
          options.has_key?(:in) &&
            (options.has_key?(:minimum) || options.has_key?(:minimum))
        end

        def minimum
          @minimum ||= options[:minimum] || options[:in].try(:min) || 0
        end

        def maximum
          @maximum ||= options[:maximum] || options[:in].try(:max) || Float::INFINITY
        end

        def to_human_size(size)
          return "∞" if size == Float::INFINITY
          ActiveSupport::NumberHelper.number_to_human_size(size)
        end

        def passes_check?(blob, check_name, check_value)
          case check_name.to_sym
          when :in
            check_value.include?(blob.byte_size)
          when :minimum
            blob.byte_size >= check_value
          when :maximum
            blob.byte_size <= check_value
          end
        end
    end

    module HelperMethods
      # Validates the size (in bytes) of the ActiveStorage attachments. Happens
      # by default on save.
      #
      #   class Employee < ActiveRecord::Base
      #     has_one_attached :avatar
      #
      #     validates_attachment_byte_size :avatar, in: 0..2.megabytes
      #   end
      #
      # Configuration options:
      # * <tt>in</tt> - a +Range+ of bytes (e.g. +0..1.megabyte+),
      # * <tt>maximum</tt> - equivalent to +in: 0..options[:maximum]+
      # * <tt>minimum</tt> - equivalent to +in: options[:minimum]..Infinity+
      # * <tt>:message</tt> - A custom error message which overrides the
      #   default error message. The following keys are available for
      #   interpolation within the message: +model+, +attribute+, +value+,
      #   +minimum+, and +maximum+.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      def validates_attachment_byte_size(*attributes)
        validates_with AttachmentByteSizeValidator, _merge_attributes(attributes)
      end
    end
  end
end
