module ActiveModel
  module MassAssignmentSecurity
    class Sanitizer
      # Returns all attributes not denied by the authorizer.
      def sanitize(attributes, authorizer)
        rejected = []
        sanitized_attributes = attributes.reject do |key, value|
          rejected << key if authorizer.deny?(key)
        end
        process_removed_attributes(rejected) unless rejected.empty?
        sanitized_attributes
      end

    protected

      def process_removed_attributes(attrs)
        raise NotImplementedError, "#process_removed_attributes(attrs) suppose to be overwritten"
      end
    end

    class LoggerSanitizer < Sanitizer
      def initialize(target)
        @target = target
        super()
      end

      def logger
        @target.logger
      end

      def logger?
        @target.respond_to?(:logger) && @target.logger
      end

      def process_removed_attributes(attrs)
        logger.warn "Can't mass-assign protected attributes: #{attrs.join(', ')}" if logger?
      end
    end

    class StrictSanitizer < Sanitizer
      def initialize(target = nil)
        super()
      end

      def process_removed_attributes(attrs)
        return if (attrs - insensitive_attributes).empty?
        raise ActiveModel::MassAssignmentSecurity::Error.new(attrs)
      end

      def insensitive_attributes
        ['id']
      end
    end

    class Error < StandardError
      def initialize(attrs)
        super("Can't mass-assign protected attributes: #{attrs.join(', ')}")
      end
    end
  end
end
