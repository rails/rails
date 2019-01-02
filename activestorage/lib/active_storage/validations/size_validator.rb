# frozen_string_literal: true

module ActiveStorage
  module Validations
    class SizeValidator < ActiveModel::EachValidator
      delegate :number_to_human_size, to: ActiveSupport::NumberHelper

      AVAILABLE_CHECKS = [:less_than, :less_than_or_equal_to, :greater_than, :greater_than_or_equal_to, :between]

      def check_validity!
        unless (AVAILABLE_CHECKS).any? { |argument| options.has_key?(argument) }
          raise ArgumentError, "You must pass either :less_than, :greater_than, or :between to the validator"
        end
      end

      def validate_each(record, attribute, value)
        files = record.send(attribute)
        # only attached
        return true unless files.attached?

        files = Array.wrap(files)

        files.each do |file|
          if content_size_valid?(file)
            record.errors.add(attribute, options[:message].presence || "size #{number_to_human_size(file.blob.byte_size)} is not between required range")
            return
          end
        end
      end

      def content_size_valid?(file)
        file_size = file.blob.byte_size
        case
        when options[:between].present?
          options[:between].exclude?(file_size)
        when options[:less_than].present?
          file_size > options[:less_than]
        when options[:less_than_or_equal_to].present?
          file_size >= options[:less_than_or_equal_to]
        when options[:greater_than].present?
          file_size < options[:greater_than]
        when options[:greater_than_or_equal_to].present?
          file_size <= options[:greater_than_or_equal_to]
        end
      end
    end
  end
end
