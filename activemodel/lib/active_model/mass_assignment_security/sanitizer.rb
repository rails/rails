module ActiveModel
  module MassAssignmentSecurity
    module Sanitizer
      # Returns all attributes not denied by the authorizer.
      def sanitize(attributes)
        sanitized_attributes = attributes.reject { |key, value| deny?(key) }
        debug_protected_attribute_removal(attributes, sanitized_attributes)
        sanitized_attributes
      end

    protected

      def debug_protected_attribute_removal(attributes, sanitized_attributes)
        removed_keys = attributes.keys - sanitized_attributes.keys
        warn!(removed_keys) if removed_keys.any?
      end

      def warn!(attrs)
        self.logger.debug "WARNING: Can't mass-assign protected attributes: #{attrs.join(', ')}" if self.logger
      end
    end
  end
end
