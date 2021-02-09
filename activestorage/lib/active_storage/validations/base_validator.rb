# frozen_string_literal: true

module ActiveStorage
  module Validations
    class BaseValidator < ActiveModel::EachValidator
      def initialize(options = {})
        super
        @error_options = { message: options[:message] }
      end

      def valid_with?(blob)
        valid = true
        each_check do |check_name, check_value|
          next if passes_check?(blob, check_name, check_value)

          @record.errors.add(@name, error_key_for(check_name), **error_options) if @record
          valid = false
        end
        valid
      end

      def validate_each(record, attribute, _value)
        @record = record
        @name = attribute

        each_blob do |blob|
          valid_with?(blob)
        end
      end

      private
        attr_reader :error_options

        def available_checks
          self.class::AVAILABLE_CHECKS
        end

        def options_blank?
          available_checks.none? { |arg| options.has_key?(arg) }
        end

        def options_redundant?
          raise NotImplementedError, "Subclasses must implement an options_redundant? method"
        end

        def error_key_for(check_name)
          raise NotImplementedError, "Subclasses must implement error_key_for(check_name)"
        end

        def each_blob(&block)
          changes = attachment_changes

          blobs =
            case
            when marked_for_creation? then changes.try(:blob) || changes.blobs
            when marked_for_deletion? then []
            else
              @record.send(blob_association)
            end

          blobs = [blobs].flatten.compact
          blobs.each { |blob| yield(blob) }
        end

        def each_check(&block)
          options.slice(*available_checks).each do |name, value|
            yield(name, value)
          end
        end

        def passes_check?(blob, check_name, check_value)
          raise NotImplementedError, "Subclasses must implement a passes_check?(blob, check_name, check_value) method"
        end

        def attachment_changes
          @attachment_changes ||= @record.attachment_changes[@name.to_s]
        end

        def marked_for_creation?
          [
            ActiveStorage::Attached::Changes::CreateOne,
            ActiveStorage::Attached::Changes::CreateMany
          ].include?(attachment_changes.class)
        end

        def marked_for_deletion?
          [
            ActiveStorage::Attached::Changes::DeleteOne,
            ActiveStorage::Attached::Changes::DeleteMany
          ].include?(attachment_changes.class)
        end

        def blob_association
          @record.respond_to?("#{@name}_blob") ? "#{@name}_blob" : "#{@name}_blobs"
        end
    end
  end
end
