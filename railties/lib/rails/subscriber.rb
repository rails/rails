require 'active_support/core_ext/class/inheritable_attributes'
require 'active_support/notifications'

module Rails
  # Rails::Subscriber is an object set to consume ActiveSupport::Notifications
  # on initialization with the sole purpose of logging. The subscriber dispatches
  # notifications to a registered object based on it's given namespace.
  #
  # An example would be an Active Record subscriber responsible for logging queries:
  #
  #   module ActiveRecord
  #     class Railtie
  #       class Subscriber < Rails::Subscriber
  #         def sql(event)
  #           "#{event.payload[:name]} (#{event.duration}) #{event.payload[:sql]}"
  #         end
  #       end
  #     end
  #   end
  #
  # Which would be registed as:
  #
  #   Rails::Subscriber.add :active_record, ActiveRecord::Railtie::Subscriber.new
  #
  # So whenever an +active_record.sql+ notification arrives to Rails::Subscriber,
  # it will properly dispatch the event (ActiveSupport::Notifications::Event) to
  # the sql method.
  #
  # This avoids spanning several subscribers just for logging purposes
  # (which slows down the main thread). It also provides a centralized
  # facility on top of Rails.logger.
  # 
  # Subscriber also has some helpers to deal with logging and automatically flushes
  # all logs when the request finishes.
  class Subscriber
    mattr_accessor :colorize_logging
    self.colorize_logging = true

    # Embed in a String to clear all previous ANSI sequences.
    CLEAR      = "\e[0m"
    BOLD       = "\e[1m"

    # Colors
    BLACK      = "\e[30m"
    RED        = "\e[31m"
    GREEN      = "\e[32m"
    YELLOW     = "\e[33m"
    BLUE       = "\e[34m"
    MAGENTA    = "\e[35m"
    CYAN       = "\e[36m"
    WHITE      = "\e[37m"

    def self.add(namespace, subscriber)
      subscribers[namespace.to_sym] = subscriber
    end

    def self.subscribers
      @subscribers ||= {}
    end

    def self.dispatch(args)
      namespace, name = args[0].split(".")
      subscriber = subscribers[namespace.to_sym]

      if subscriber.respond_to?(name) && subscriber.logger
        begin
          subscriber.send(name, ActiveSupport::Notifications::Event.new(*args))
        rescue Exception => e
          Rails.logger.error "Could not log #{args[0].inspect} event. #{e.class}: #{e.message}"
        end
      end
    end

    # Flush all subscribers' logger.
    def self.flush_all!
      loggers = subscribers.values.map(&:logger)
      loggers.uniq!
      loggers.each { |l| l.flush if l.respond_to?(:flush) }
    end

    # By default, we use the Rails.logger for logging.
    def logger
      Rails.logger
    end

  protected

    %w(info debug warn error fatal unknown).each do |level|
      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{level}(*args, &block)
          logger.#{level}(*args, &block)
        end
      METHOD
    end

    # Set color by using a string or one of the defined constants. If a third
    # option is set to true, it also adds bold to the string. This is based
    # on Highline implementation and it automatically appends CLEAR to the end
    # of the returned String.
    def color(text, color, bold=false)
      return text unless colorize_logging
      color = self.class.const_get(color.to_s.upcase) if color.is_a?(Symbol)
      bold  = bold ? BOLD : ""
      "#{bold}#{color}#{text}#{CLEAR}"
    end
  end
end