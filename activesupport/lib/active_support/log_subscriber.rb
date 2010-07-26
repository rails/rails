require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/class/attribute'

module ActiveSupport
  # ActiveSupport::LogSubscriber is an object set to consume ActiveSupport::Notifications
  # with solely purpose of logging. The log subscriber dispatches notifications to a
  # regirested object based on its given namespace.
  #
  # An example would be Active Record log subscriber responsible for logging queries:
  #
  #   module ActiveRecord
  #     class LogSubscriber < ActiveSupport::LogSubscriber
  #       def sql(event)
  #         "#{event.payload[:name]} (#{event.duration}) #{event.payload[:sql]}"
  #       end
  #     end
  #   end
  #
  # And it's finally registed as:
  #
  #   ActiveRecord::LogSubscriber.attach_to :active_record
  #
  # Since we need to know all instance methods before attaching the log subscriber,
  # the line above should be called after your ActiveRecord::LogSubscriber definition.
  #
  # After configured, whenever a "sql.active_record" notification is published,
  # it will properly dispatch the event (ActiveSupport::Notifications::Event) to
  # the sql method.
  #
  # Log subscriber also has some helpers to deal with logging and automatically flushes
  # all logs when the request finishes (via action_dispatch.callback notification) in
  # a Rails environment.
  class LogSubscriber
    mattr_accessor :colorize_logging
    self.colorize_logging = true

    class_attribute :logger

    class << self
      remove_method :logger
    end

    def self.logger
      @logger ||= Rails.logger if defined?(Rails)
    end

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

    def self.attach_to(namespace, log_subscriber=new, notifier=ActiveSupport::Notifications)
      log_subscribers << log_subscriber
      @@flushable_loggers = nil

      log_subscriber.public_methods(false).each do |event|
        next if 'call' == event.to_s

        notifier.subscribe("#{event}.#{namespace}", log_subscriber)
      end
    end

    def self.log_subscribers
      @@log_subscribers ||= []
    end

    def self.flushable_loggers
      @@flushable_loggers ||= begin
        loggers = log_subscribers.map(&:logger)
        loggers.uniq!
        loggers.select { |l| l.respond_to?(:flush) }
      end
    end

    # Flush all log_subscribers' logger.
    def self.flush_all!
      flushable_loggers.each(&:flush)
    end

    def call(message, *args)
      return unless logger

      method = message.split('.').first
      begin
        send(method, ActiveSupport::Notifications::Event.new(message, *args))
      rescue Exception => e
        logger.error "Could not log #{message.inspect} event. #{e.class}: #{e.message}"
      end
    end

  protected

    %w(info debug warn error fatal unknown).each do |level|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{level}(*args, &block)
          return unless logger
          logger.#{level}(*args, &block)
        end
      METHOD
    end

    # Set color by using a string or one of the defined constants. If a third
    # option is set to true, it also adds bold to the string. This is based
    # on Highline implementation and it automatically appends CLEAR to the end
    # of the returned String.
    #
    def color(text, color, bold=false)
      return text unless colorize_logging
      color = self.class.const_get(color.to_s.upcase) if color.is_a?(Symbol)
      bold  = bold ? BOLD : ""
      "#{bold}#{color}#{text}#{CLEAR}"
    end
  end
end
