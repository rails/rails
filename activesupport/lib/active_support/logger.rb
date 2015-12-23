require 'active_support/logger_silence'
require 'logger'

module ActiveSupport
  class Logger < ::Logger
    include LoggerSilence

    # If +true+, will broadcast all messages sent to this logger to the any
    # logger linked to this one via +broadcast+.
    #
    # If +false+, the logger will still forward calls to +close+, +progname=+,
    # +formatter=+ and +level+ to any linked loggers, but no calls to +add+ or
    # +<<+.
    #
    # Defaults to +true+.
    attr_accessor :broadcast_messages # :nodoc:

    # Broadcasts logs to multiple loggers.
    def self.broadcast(logger) # :nodoc:
      Module.new do
        define_method(:add) do |*args, &block|
          logger.add(*args, &block) if broadcast_messages
          super(*args, &block)
        end

        define_method(:<<) do |x|
          logger << x if broadcast_messages
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
      @broadcast_messages = true
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
