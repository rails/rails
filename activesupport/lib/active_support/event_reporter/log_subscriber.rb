# frozen_string_literal: true

module ActiveSupport
  class EventReporter
    class LogSubscriber
      include ColorizeLogging

      LEVEL_CHECKS = {
        debug: -> (logger) { logger.debug? },
        info: -> (logger) { logger.info? },
        error: -> (logger) { logger.error? },
      }

      class << self
        def event_log_level(method_name, level)
          log_levels[method_name] = level
        end

        def logger
          @logger || default_logger
        end

        def default_logger
          raise NotImplementedError
        end

        attr_writer :logger
        attr_accessor :namespace
      end

      class_attribute :log_levels, default: {} # :nodoc:

      def emit(event)
        event_method = [event[:name].split(".").take(2)].to_h[namespace]&.to_sym
        public_send(event_method, event) if LEVEL_CHECKS[log_levels[event_method]]&.call(logger)
      end

      def logger
        self.class.logger
      end

      private
        def namespace
          self.class.namespace
        end
    end
  end
end
