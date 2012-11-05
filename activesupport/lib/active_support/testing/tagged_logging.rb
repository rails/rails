module ActiveSupport
  module Testing
    module TaggedLogging
      attr_writer :tagged_logger

      def before_setup
        tagged_logger.push_tags(self.class.name, __name__) if tagged_logging?
        super
      end

      def after_teardown
        super
        tagged_logger.pop_tags(2) if tagged_logging?
      end

      private
        def tagged_logger
          @tagged_logger ||= (defined?(Rails.logger) && Rails.logger)
        end

        def tagged_logging?
          tagged_logger && tagged_logger.respond_to?(:push_tags)
        end
    end
  end
end
