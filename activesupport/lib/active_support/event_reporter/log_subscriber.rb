# :markup: markdown
# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/enumerable"

module ActiveSupport
  class EventReporter
    class LogSubscriber
      include ColorizeLogging

      LOG_LEVELS = [:debug, :info, :warn, :error].freeze
      LOG_LEVEL_PREDICATES = LOG_LEVELS.index_with { |level| :"#{level}?" }.freeze # :nodoc:

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

      private
        def namespace
          self.class.namespace
        end

        def log_level_satisfied?(event_method)
          predicate = LOG_LEVEL_PREDICATES[log_levels[event_method]]
          return false unless predicate

          logger.public_send(predicate)
        end
    end
  end
end
