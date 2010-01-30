module ActiveRecord
  module MassAssignmentSecurity
    module Sanitizer

      # Returns all attributes not denied by the authorizer.
      def sanitize(attributes)
        sanitized_attributes = attributes.reject { |key, value| deny?(key) }
        debug_protected_attribute_removal(attributes, sanitized_attributes) if debug?
        sanitized_attributes
      end

      protected

        def debug_protected_attribute_removal(attributes, sanitized_attributes)
          removed_keys = attributes.keys - sanitized_attributes.keys
          if removed_keys.any?
            logger.debug "WARNING: Can't mass-assign protected attributes: #{removed_keys.join(', ')}"
          end
        end

        def debug?
          logger.present?
        end

    end
  end
end
