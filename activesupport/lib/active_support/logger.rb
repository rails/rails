require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/logger_silence'
require 'logger'

module ActiveSupport
  class Logger < ::Logger
    include LoggerSilence

    # Broadcasts logs to multiple loggers.
    def self.broadcast(logger) # :nodoc:
      Module.new do
        define_method(:add) do |*args, &block|
          logger.add(*args, &block)
          super(*args, &block)
        end

        define_method(:<<) do |x|
          logger << x
          super(x)
        end

        define_method(:close) do
          logger.close
          super()
        end

        define_method(:progname=) do |name|
          logger.progname = name
          super(name)
        end

        define_method(:formatter=) do |formatter|
          logger.formatter = formatter
          super(formatter)
        end

        define_method(:level=) do |level|
          logger.level = level
          super(level)
        end
      end
    end

    def initialize(*args)
      super
      @formatter = SimpleFormatter.new
      after_initialize if respond_to? :after_initialize
    end

    def add(severity, message = nil, progname = nil, &block)
      return true if @logdev.nil? || (severity || UNKNOWN) < level
      super
    end

    Logger::Severity.constants.each do |severity|
      class_eval(<<-EOT, __FILE__, __LINE__ + 1)
        def #{severity.downcase}?                # def debug?
          Logger::#{severity} >= level           #   DEBUG >= level
        end                                      # end
      EOT
    end

    # Simple formatter which only displays the message.
    class SimpleFormatter < ::Logger::Formatter
      # This method is invoked when a log event occurs
      def call(severity, timestamp, progname, msg)
        "#{String === msg ? msg : msg.inspect}\n"
      end
    end
  end
end
