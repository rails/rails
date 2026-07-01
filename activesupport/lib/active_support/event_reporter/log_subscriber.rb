# frozen_string_literal: true

module ActiveSupport
  class EventReporter
    class LogSubscriber
      include ColorizeLogging

      LOG_LEVELS = [:debug, :info, :error].freeze

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
        return unless logger
        name = event[:name]
        event_method = name[name.index(".") + 1, name.length]

        public_send(event_method, event) if log_level_satisfied?(event_method)
      end

      def logger
        self.class.logger
      end

      private
        def namespace
          self.class.namespace
        end

        def log_level_satisfied?(event_method)
          event_log_level = log_levels[event_method]
          return false unless LOG_LEVELS.include?(event_log_level)

          logger.public_send("#{event_log_level}?")
        end
    end
  end
end
