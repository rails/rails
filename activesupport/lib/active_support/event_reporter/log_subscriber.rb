# :markup: markdown
# frozen_string_literal: true

require "active_support/core_ext/class/attribute"

module ActiveSupport
  class EventReporter
    class LogSubscriber
      include ColorizeLogging

      LOG_LEVELS = [:debug, :info, :error].freeze

      class << self
        def event_log_level(method_name, level)
          self.log_levels = log_levels.merge(method_name.to_s => level).freeze
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
          prefix = "#{namespace}.".freeze
          proc do |event|
            event[:name].start_with?(prefix)
          end
        end
      end

      class_attribute :log_levels, default: {}.freeze # :nodoc:

      def emit(event)
        return unless logger
        name = event[:name]
        event_method = name[name.index(".") + 1, name.length]

        public_send(event_method, event) if log_level_satisfied?(event_method)
      end

      def logger
        self.class.logger
      end

      # Returns the logger level predicates (e.g. +:info?+) that #emit would check
      # for events named <tt>"#{namespace}.*"</tt> passing +filter+, or +nil+ if
      # that cannot be determined without emitting the event.
      def log_level_predicates_for(namespace, filter) # :nodoc:
        return unless method(:emit).owner == LogSubscriber && method(:log_level_satisfied?).owner == LogSubscriber

        predicates = log_levels.filter_map do |event_method, level|
          next unless LOG_LEVELS.include?(level)
          next if filter && !filter.call({ name: "#{namespace}.#{event_method}" })

          :"#{level}?"
        end
        predicates.uniq.freeze
      rescue StandardError
        nil
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
