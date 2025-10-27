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
          log_levels[method_name.to_s] = level
        end

        def logger
          @logger || default_logger
        end

        def default_logger
          raise NotImplementedError
        end

        attr_writer :logger
        attr_accessor :namespace

        def subscription_filter
          namespace = self.namespace.to_s
          proc do |event|
            name = event[:name]
            if (dot_idx = name.index("."))
              event_namespace = name[0, dot_idx]
              namespace == event_namespace
            end
          end
        end
      end

      class_attribute :log_levels, default: {} # :nodoc:

      def emit(event)
        name = event[:name]
        event_method = name[name.index(".") + 1, name.length]
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
