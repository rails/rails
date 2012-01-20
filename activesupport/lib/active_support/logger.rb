require 'logger'

module ActiveSupport
  # Broadcasts logs to multiple loggers
  class BroadcastLogger < ::Logger # :nodoc:
    attr_reader :logs

    def initialize(logs)
      super(nil)
      @logs = logs
    end

    def progname
      logs.first.progname
    end

    def progname=(name)
      logs.each { |x| x.progname = name }
    end

    def formatter
      logs.first.formatter
    end

    def formatter=(formatter)
      logs.each { |x| x.formatter = formatter }
    end

    def level
      logs.first.level
    end

    def level=(level)
      logs.each { |x| x.level = level }
    end

    def add(severity, message = nil, progname = nil, &block)
      super
      logs.each { |l| l.add(severity, message, progname, &block) }
    end

    def <<(x)
      logs.each { |l| l << x }
    end

    def close
      logs.each(&:close)
    end
  end

  class Logger < ::Logger
    def initialize(*args)
      super
      @formatter = SimpleFormatter.new
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
