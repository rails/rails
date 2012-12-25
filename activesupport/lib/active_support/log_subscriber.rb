require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/class/attribute'

module ActiveSupport
  # ActiveSupport::LogSubscriber is an object set to consume
  # ActiveSupport::Notifications with the sole purpose of logging them.
  # The log subscriber dispatches notifications to a registered object based
  # on its given namespace.
  #
  # An example would be Active Record log subscriber responsible for logging
  # queries:
  #
  #   module ActiveRecord
  #     class LogSubscriber < ActiveSupport::LogSubscriber
  #       def sql(event)
  #         "#{event.payload[:name]} (#{event.duration}) #{event.payload[:sql]}"
  #       end
  #     end
  #   end
  #
  # And it's finally registered as:
  #
  #   ActiveRecord::LogSubscriber.attach_to :active_record
  #
  # Since we need to know all instance methods before attaching the log
  # subscriber, the line above should be called after your
  # <tt>ActiveRecord::LogSubscriber</tt> definition.
  #
  # After configured, whenever a "sql.active_record" notification is published,
  # it will properly dispatch the event (ActiveSupport::Notifications::Event) to
  # the sql method.
  #
  # Log subscriber also has some helpers to deal with logging and automatically
  # flushes all logs when the request finishes (via action_dispatch.callback
  # notification) in a Rails environment.
  class LogSubscriber
    # Embed in a String to clear all previous ANSI sequences.
    CLEAR   = "\e[0m"
    BOLD    = "\e[1m"

    # Colors
    BLACK   = "\e[30m"
    RED     = "\e[31m"
    GREEN   = "\e[32m"
    YELLOW  = "\e[33m"
    BLUE    = "\e[34m"
    MAGENTA = "\e[35m"
    CYAN    = "\e[36m"
    WHITE   = "\e[37m"

    mattr_accessor :colorize_logging
    self.colorize_logging = true

    class << self
      def logger
        @logger ||= Rails.logger if defined?(Rails)
        @logger
      end

      attr_writer :logger

      def attach_to(namespace, log_subscriber=new, notifier=ActiveSupport::Notifications)
        log_subscribers << log_subscriber

        log_subscriber.public_methods(false).each do |event|
          next if %w{ start finish }.include?(event.to_s)

          notifier.subscribe("#{event}.#{namespace}", log_subscriber)
        end
      end

      def log_subscribers
        @@log_subscribers ||= []
      end

      # Flush all log_subscribers' logger.
      def flush_all!
        logger.flush if logger.respond_to?(:flush)
      end
    end

    def initialize
      @queue_key = [self.class.name, object_id].join  "-"
      super
    end

    def logger
      LogSubscriber.logger
    end

    def start(name, id, payload)
      return unless logger

      e = ActiveSupport::Notifications::Event.new(name, Time.now, nil, id, payload)
      parent = event_stack.last
      parent << e if parent

      event_stack.push e
    end

    def finish(name, id, payload)
      return unless logger

      finished  = Time.now
      event     = event_stack.pop
      event.end = finished
      event.payload.merge!(payload)

      method = name.split('.').first
      begin
        send(method, event)
      rescue Exception => e
        logger.error "Could not log #{name.inspect} event. #{e.class}: #{e.message} #{e.backtrace}"
      end
    end

  protected

    %w(info debug warn error fatal unknown).each do |level|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{level}(progname = nil, &block)
          logger.#{level}(progname, &block) if logger
        end
      METHOD
    end

    # Set color by using a string or one of the defined constants. If a third
    # option is set to +true+, it also adds bold to the string. This is based
    # on the Highline implementation and will automatically append CLEAR to the
    # end of the returned String.
    def color(text, color, bold=false)
      return text unless colorize_logging
      color = self.class.const_get(color.upcase) if color.is_a?(Symbol)
      bold  = bold ? BOLD : ""
      "#{bold}#{color}#{text}#{CLEAR}"
    end

    private

    def event_stack
      Thread.current[@queue_key] ||= []
    end
  end
end
