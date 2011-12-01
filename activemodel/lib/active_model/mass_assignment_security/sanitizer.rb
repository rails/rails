require 'active_support/core_ext/module/delegation'

module ActiveModel
  module MassAssignmentSecurity
    class Sanitizer
      def initialize(target=nil)
      end

      # Returns all attributes not denied by the authorizer.
      def sanitize(attributes, authorizer)
        sanitized_attributes = attributes.reject { |key, value| authorizer.deny?(key) }
        debug_protected_attribute_removal(attributes, sanitized_attributes)
        sanitized_attributes
      end

    protected

      def debug_protected_attribute_removal(attributes, sanitized_attributes)
        removed_keys = attributes.keys - sanitized_attributes.keys
        process_removed_attributes(removed_keys) if removed_keys.any?
      end

      def process_removed_attributes(attrs)
        raise NotImplementedError, "#process_removed_attributes(attrs) suppose to be overwritten"
      end
    end

    class LoggerSanitizer < Sanitizer
      delegate :logger, :to => :@target

      def initialize(target)
        @target = target
        super
      end

      def logger?
        @target.respond_to?(:logger) && @target.logger
      end

      def process_removed_attributes(attrs)
        logger.debug "WARNING: Can't mass-assign protected attributes: #{attrs.join(', ')}" if logger?
      end
    end

    class StrictSanitizer < Sanitizer
      def process_removed_attributes(attrs)
        return if (attrs - insensitive_attributes).empty?
        raise ActiveModel::MassAssignmentSecurity::Error, "Can't mass-assign protected attributes: #{attrs.join(', ')}"
      end

      def insensitive_attributes
        ['id']
      end
    end

    class Error < StandardError
    end
  end
end
