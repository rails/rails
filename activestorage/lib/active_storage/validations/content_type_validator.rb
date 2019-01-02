# frozen_string_literal: true

module ActiveStorage
  module Validations
    class ContentTypeValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        files = record.send(attribute)

        return true unless files.attached?
        return true if types.empty?

        files = Array.wrap(files)

        errors_options = { authorized_types: types_to_human_format }
        errors_options[:message] = options[:message] if options[:message].present?

        files.each do |file|
          unless content_type_valid?(file)
            errors_options[:content_type] = content_type(file)

            record.errors.add(attribute, :content_type_invalid, errors_options)
            return
          end
        end
      end

      def types
        Array.wrap(options[:with]) + Array.wrap(options[:in])
      end

      def types_to_human_format
        types.join(", ")
      end

      def content_type(file)
        file.blob.present? && file.blob.content_type
      end

      def content_type_valid?(file)
        file.blob.present? && file.blob.content_type.in?(types)
      end
    end
  end
end
