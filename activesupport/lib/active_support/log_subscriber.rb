# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"
require "active_support/core_ext/class/attribute"
require "active_support/core_ext/enumerable"
require "active_support/subscriber"
require "active_support/deprecation/proxy_wrappers"

module ActiveSupport
  # = Active Support Log \Subscriber
  #
  # +ActiveSupport::LogSubscriber+ is an object set to consume
  # ActiveSupport::Notifications with the sole purpose of logging them.
  # The log subscriber dispatches notifications to a registered object based
  # on its given namespace.
  #
  # An example would be Active Record log subscriber responsible for logging
  # queries:
  #
  #   module ActiveRecord
  #     class LogSubscriber < ActiveSupport::LogSubscriber
  #       attach_to :active_record
  #
  #       def sql(event)
  #         info "#{event.payload[:name]} (#{event.duration}) #{event.payload[:sql]}"
  #       end
  #     end
  #   end
  #
  # ActiveRecord::LogSubscriber.logger must be set as well, but it is assigned
  # automatically in a \Rails environment.
  #
  # After configured, whenever a <tt>"sql.active_record"</tt> notification is
  # published, it will properly dispatch the event
  # (ActiveSupport::Notifications::Event) to the +sql+ method.
  #
  # Being an ActiveSupport::Notifications consumer,
  # +ActiveSupport::LogSubscriber+ exposes a simple interface to check if
  # instrumented code raises an exception. It is common to log a different
  # message in case of an error, and this can be achieved by extending
  # the previous example:
  #
  #   module ActiveRecord
  #     class LogSubscriber < ActiveSupport::LogSubscriber
  #       def sql(event)
  #         exception = event.payload[:exception]
  #
  #         if exception
  #           exception_object = event.payload[:exception_object]
  #
  #           error "[ERROR] #{event.payload[:name]}: #{exception.join(', ')} " \
  #                 "(#{exception_object.backtrace.first})"
  #         else
  #           # standard logger code
  #         end
  #       end
  #     end
  #   end
  #
  # +ActiveSupport::LogSubscriber+ also has some helpers to deal with
  # logging. For example, ActiveSupport::LogSubscriber.flush_all! will ensure
  # that all logs are flushed, and it is called in Rails::Rack::Logger after a
  # request finishes.
  class LogSubscriber < Subscriber
    # ANSI sequence modes
    MODES = {
      clear:     0,
      bold:      1,
      italic:    3,
      underline: 4,
    }

    # ANSI sequence colors
    BLACK   = "\e[30m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    WHITE   = "\e[37m"

    mattr_accessor :colorize_logging, default: true
    class_attribute :log_levels, instance_accessor: false, default: {} # :nodoc:

    LEVEL_CHECKS = {
      debug: -> (logger) { !logger.debug? },
      info: -> (logger) { !logger.info? },
      error: -> (logger) { !logger.error? },
    }

    class << self
      def logger
        @logger ||= if defined?(Rails) && Rails.respond_to?(:logger)
          Rails.logger
        end
      end

      def attach_to(...) # :nodoc:
        result = super
        set_event_levels
        result
      end

      attr_writer :logger

      def log_subscribers
        subscribers
      end

      # Flush all log_subscribers' logger.
      def flush_all!
        logger.flush if logger.respond_to?(:flush)
      end

      private
        def fetch_public_methods(subscriber, inherit_all)
          subscriber.public_methods(inherit_all) - LogSubscriber.public_instance_methods(true)
        end

        def set_event_levels
          if subscriber
            subscriber.event_levels = log_levels.transform_keys { |k| "#{k}.#{namespace}" }
          end
        end

        def subscribe_log_level(method, level)
          self.log_levels = log_levels.merge(method => LEVEL_CHECKS.fetch(level))
          set_event_levels
        end
    end

    def initialize
      super
      @event_levels = {}
    end

    def logger
      LogSubscriber.logger
    end

    def silenced?(event)
      logger.nil? || @event_levels[event]&.call(logger)
    end

    def call(event)
      super if logger
    rescue => e
      log_exception(event.name, e)
    end

    def publish_event(event)
      super if logger
    rescue => e
      log_exception(event.name, e)
    end

    attr_writer :event_levels # :nodoc:

  private
    %w(info debug warn error fatal unknown).each do |level|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{level}(progname = nil, &block)
          logger.#{level}(progname, &block) if logger
        end
      METHOD
    end

    # Set color by using a symbol or one of the defined constants. Set modes
    # by specifying bold, italic, or underline options. Inspired by Highline,
    # this method will automatically clear formatting at the end of the returned String.
    def color(text, color, mode_options = {}) # :doc:
      return text unless colorize_logging
      color = self.class.const_get(color.upcase) if color.is_a?(Symbol)
      mode = mode_from(mode_options)
      clear = "\e[#{MODES[:clear]}m"
      "#{mode}#{color}#{text}#{clear}"
    end

    def mode_from(options)
      modes = MODES.values_at(*options.compact_blank.keys)

      "\e[#{modes.join(";")}m" if modes.any?
    end

    def log_exception(name, e)
      if logger
        logger.error "Could not log #{name.inspect} event. #{e.class}: #{e.message} #{e.backtrace}"
      end
    end
  end
end
