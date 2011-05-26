module ActiveModel
  module MassAssignmentSecurity
    module Sanitizer

      # Returns all attributes not denied by the authorizer.
      def sanitize(attributes, strict = false)
        sanitized_attributes = attributes.reject { |key, value| deny?(key) }
        debug_protected_attribute_removal(attributes, sanitized_attributes, strict)
        sanitized_attributes
      end

      protected

      def debug_protected_attribute_removal(attributes, sanitized_attributes, strict)
        removed_keys = attributes.keys - sanitized_attributes.keys
        process_removed_keys(removed_keys, strict) if removed_keys.any?
      end

      def process_removed_keys(attrs, strict)
        message = "Can't mass-assign protected attributes: #{attrs.join(', ')}"
        if strict
          raise ActiveModel::MassAssignmentSecurity::Error.new(message, attrs)
        else
          self.logger.debug "WARNING: #{message}" if self.logger
        end
      end
    end

    class Error < StandardError
      
      attr_accessor :attrs
      
      def initialize(message, attrs)
        super(message)
        self.attrs = attrs
      end

    end
  end
end
