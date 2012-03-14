module ActiveModel
  module MassAssignmentSecurity
    class Sanitizer
      # Returns all attributes not denied by the authorizer.
      def sanitize(attributes, authorizer)
        attributes.reject do |attr, value|
          if authorizer.deny?(attr)
            process_removed_attribute(attr)
            true
          end
        end
      end

    protected

      def process_removed_attribute(attr)
        raise NotImplementedError, "#process_removed_attribute(attr) suppose to be overwritten"
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

      def process_removed_attribute(attr)
        logger.warn "Can't mass-assign protected attribute: #{attr}" if logger?
      end
    end

    class StrictSanitizer < Sanitizer
      def initialize(target = nil)
        super()
      end

      def process_removed_attribute(attr)
        return if insensitive_attributes.include?(attr)
        raise ActiveModel::MassAssignmentSecurity::Error.new(attr)
      end

      def insensitive_attributes
        @insensitive_attributes ||= ['id']
      end
    end

    class Error < StandardError
      def initialize(attr)
        super("Can't mass-assign protected attribute: #{attr}")
      end
    end
  end
end
