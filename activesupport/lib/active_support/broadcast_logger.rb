# frozen_string_literal: true

module ActiveSupport
  # = Active Support Broadcast Logger
  #
  # The Broadcast logger is a logger used to write messages to multiple IO. It is commonly used
  # in development to display messages on STDOUT and also write them to a file (development.log).
  # With the Broadcast logger, you can broadcast your logs to a unlimited number of sinks.
  #
  # The BroadcastLogger acts as a standard logger and all methods you are used to are available.
  # However, all the methods on this logger will propagate and be delegated to the other loggers
  # that are part of the broadcast.
  #
  # Broadcasting your logs.
  #
  #   stdout_logger = Logger.new(STDOUT)
  #   file_logger   = Logger.new("development.log")
  #   broadcast = BroadcastLogger.new(stdout_logger, file_logger)
  #
  #   broadcast.info("Hello world!") # Writes the log to STDOUT and the development.log file.
  #
  # Add a logger to the broadcast.
  #
  #   stdout_logger = Logger.new(STDOUT)
  #   broadcast = BroadcastLogger.new(stdout_logger)
  #   file_logger   = Logger.new("development.log")
  #   broadcast.broadcast_to(file_logger)
  #
  #   broadcast.info("Hello world!") # Writes the log to STDOUT and the development.log file.
  #
  # Modifying the log level for all broadcasted loggers.
  #
  #   stdout_logger = Logger.new(STDOUT)
  #   file_logger   = Logger.new("development.log")
  #   broadcast = BroadcastLogger.new(stdout_logger, file_logger)
  #
  #   broadcast.level = Logger::FATAL # Modify the log level for the whole broadcast.
  #
  # Stop broadcasting log to a sink.
  #
  #   stdout_logger = Logger.new(STDOUT)
  #   file_logger   = Logger.new("development.log")
  #   broadcast = BroadcastLogger.new(stdout_logger, file_logger)
  #   broadcast.info("Hello world!") # Writes the log to STDOUT and the development.log file.
  #
  #   broadcast.stop_broadcasting_to(file_logger)
  #   broadcast.info("Hello world!") # Writes the log *only* to STDOUT.
  #
  # At least one sink has to be part of the broadcast. Otherwise, your logs will not
  # be written anywhere. For instance:
  #
  #   broadcast = BroadcastLogger.new
  #   broadcast.info("Hello world") # The log message will appear nowhere.
  #
  # If you are adding a custom logger with custom methods to the broadcast,
  # the `BroadcastLogger` will proxy them and return the raw value, or an array
  # of raw values, depending on how many loggers in the broadcasts responded to
  # the method:
  #
  #   class MyLogger < ::Logger
  #     def loggable?
  #       true
  #     end
  #   end
  #
  #   logger = BroadcastLogger.new
  #   logger.loggable? # => A NoMethodError exception is raised because no loggers in the broadcasts could respond.
  #
  #   logger.broadcast_to(MyLogger.new(STDOUT))
  #   logger.loggable? # => true
  #   logger.broadcast_to(MyLogger.new(STDOUT))
  #   puts logger.broadcasts # => [MyLogger, MyLogger]
  #   logger.loggable? # [true, true]
  class BroadcastLogger
    include ActiveSupport::LoggerSilence

    # Returns all the logger that are part of this broadcast.
    attr_reader :broadcasts
    attr_reader :formatter
    attr_accessor :progname

    def initialize(*loggers)
      @broadcasts = []
      @progname = "Broadcast"

      broadcast_to(*loggers)
    end

    # Add logger(s) to the broadcast.
    #
    #   broadcast_logger = ActiveSupport::BroadcastLogger.new
    #   broadcast_logger.broadcast_to(Logger.new(STDOUT), Logger.new(STDERR))
    def broadcast_to(*loggers)
      @broadcasts.concat(loggers)
    end

    # Remove a logger from the broadcast. When a logger is removed, messages sent to
    # the broadcast will no longer be written to its sink.
    #
    #   sink = Logger.new(STDOUT)
    #   broadcast_logger = ActiveSupport::BroadcastLogger.new
    #
    #   broadcast_logger.stop_broadcasting_to(sink)
    def stop_broadcasting_to(logger)
      @broadcasts.delete(logger)
    end

    def level
      @broadcasts.map(&:level).min
    end

    def <<(message)
      dispatch { |logger| logger.<<(message) }
    end

    def add(*args, &block)
      dispatch { |logger| logger.add(*args, &block) }
    end
    alias_method :log, :add

    def debug(*args, &block)
      dispatch { |logger| logger.debug(*args, &block) }
    end

    def info(*args, &block)
      dispatch { |logger| logger.info(*args, &block) }
    end

    def warn(*args, &block)
      dispatch { |logger| logger.warn(*args, &block) }
    end

    def error(*args, &block)
      dispatch { |logger| logger.error(*args, &block) }
    end

    def fatal(*args, &block)
      dispatch { |logger| logger.fatal(*args, &block) }
    end

    def unknown(*args, &block)
      dispatch { |logger| logger.unknown(*args, &block) }
    end

    def formatter=(formatter)
      dispatch { |logger| logger.formatter = formatter }

      @formatter = formatter
    end

    def level=(level)
      dispatch { |logger| logger.level = level }
    end
    alias_method :sev_threshold=, :level=

    def local_level=(level)
      dispatch do |logger|
        logger.local_level = level if logger.respond_to?(:local_level=)
      end
    end

    def close
      dispatch { |logger| logger.close }
    end

    # +True+ if the log level allows entries with severity Logger::DEBUG to be written
    # to at least one broadcast. +False+ otherwise.
    def debug?
      @broadcasts.any? { |logger| logger.debug? }
    end

    # Sets the log level to Logger::DEBUG for the whole broadcast.
    def debug!
      dispatch { |logger| logger.debug! }
    end

    # +True+ if the log level allows entries with severity Logger::INFO to be written
    # to at least one broadcast. +False+ otherwise.
    def info?
      @broadcasts.any? { |logger| logger.info? }
    end

    # Sets the log level to Logger::INFO for the whole broadcast.
    def info!
      dispatch { |logger| logger.info! }
    end

    # +True+ if the log level allows entries with severity Logger::WARN to be written
    # to at least one broadcast. +False+ otherwise.
    def warn?
      @broadcasts.any? { |logger| logger.warn? }
    end

    # Sets the log level to Logger::WARN for the whole broadcast.
    def warn!
      dispatch { |logger| logger.warn! }
    end

    # +True+ if the log level allows entries with severity Logger::ERROR to be written
    # to at least one broadcast. +False+ otherwise.
    def error?
      @broadcasts.any? { |logger| logger.error? }
    end

    # Sets the log level to Logger::ERROR for the whole broadcast.
    def error!
      dispatch { |logger| logger.error! }
    end

    # +True+ if the log level allows entries with severity Logger::FATAL to be written
    # to at least one broadcast. +False+ otherwise.
    def fatal?
      @broadcasts.any? { |logger| logger.fatal? }
    end

    # Sets the log level to Logger::FATAL for the whole broadcast.
    def fatal!
      dispatch { |logger| logger.fatal! }
    end

    def initialize_copy(other)
      @broadcasts = []
      @progname = other.progname.dup
      @formatter = other.formatter.dup

      broadcast_to(*other.broadcasts.map(&:dup))
    end

    private
      def dispatch(&block)
        @broadcasts.each { |logger| block.call(logger) }
      end

      def method_missing(name, *args, **kwargs, &block)
        loggers = @broadcasts.select { |logger| logger.respond_to?(name) }

        if loggers.none?
          super(name, *args, **kwargs, &block)
        elsif loggers.one?
          loggers.first.send(name, *args, **kwargs, &block)
        else
          loggers.map { |logger| logger.send(name, *args, **kwargs, &block) }
        end
      end

      def respond_to_missing?(method, include_all)
        @broadcasts.any? { |logger| logger.respond_to?(method, include_all) }
      end
  end
end
