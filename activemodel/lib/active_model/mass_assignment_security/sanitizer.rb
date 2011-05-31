module ActiveModel
  module MassAssignmentSecurity
    class Sanitizer
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

      attr_accessor :logger

      def initialize(logger = nil)
        self.logger = logger
        super()
      end
      
      def process_removed_attributes(attrs)
        self.logger.debug "WARNING: Can't mass-assign protected attributes: #{attrs.join(', ')}" if self.logger
      end
    end

    class StrictSanitizer < Sanitizer
      def process_removed_attributes(attrs)
        raise ActiveModel::MassAssignmentSecurity::Error, "Can't mass-assign protected attributes: #{attrs.join(', ')}"
      end
    end

    class Error < StandardError
    end

  end
end
