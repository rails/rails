module ActiveModel
  module MassAssignmentSecurity
    class Sanitizer #:nodoc:
      # Returns all attributes not denied by the authorizer.
      def sanitize(klass, attributes, authorizer)
        rejected = []
        sanitized_attributes = attributes.reject do |key, value|
          rejected << key if authorizer.deny?(key)
        end
        process_removed_attributes(klass, rejected) unless rejected.empty?
        sanitized_attributes
      end

    protected

      def process_removed_attributes(klass, attrs)
        raise NotImplementedError, "#process_removed_attributes(attrs) suppose to be overwritten"
      end
    end

    class LoggerSanitizer < Sanitizer #:nodoc:
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

      def backtrace
        if defined? Rails
          Rails.backtrace_cleaner.clean(caller)
        else
          caller
        end
      end

      def process_removed_attributes(klass, attrs)
        if logger?
          logger.warn do
            "WARNING: Can't mass-assign protected attributes for #{klass.name}: #{attrs.join(', ')}\n" +
                backtrace.map { |trace| "\t#{trace}" }.join("\n")
          end
        end
      end
    end

    class StrictSanitizer < Sanitizer #:nodoc:
      def initialize(target = nil)
        super()
      end

      def process_removed_attributes(klass, attrs)
        return if (attrs - insensitive_attributes).empty?
        raise ActiveModel::MassAssignmentSecurity::Error.new(klass, attrs)
      end

      def insensitive_attributes
        ['id']
      end
    end

    class Error < StandardError #:nodoc:
      def initialize(klass, attrs)
        super("Can't mass-assign protected attributes for #{klass.name}: #{attrs.join(', ')}")
      end
    end
  end
end
