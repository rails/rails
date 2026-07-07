# frozen_string_literal: true

require "logger"
require "active_support/logger_silence"

module ActiveSupport
  # = Active Support Proxy Logger
  #
  # The proxy logger, is a logger that forwards all received logs to another
  # logger, but has its own independent severity level.
  #
  # This is useful when you want some library you have no control over to use
  # the same logger as the rest of your application, but to have a different severity
  # level because it is logging too much:
  #
  #   SomeLibrary.logger = ActiveSupport::ProxyLogger.new(Rails.logger, :error)
  #
  # Almost all of the standard Logger interface is supported.
  #
  # Note that the proxy logger can only surpress some logs, if the proxy severity is lower
  # than the severity of the proxied logger, the logs won't be emitted.
  class ProxyLogger
    include LoggerSilence
    include ::Logger::Severity

    def initialize(logger, level = ::Logger::DEBUG)
      super()
      @logger = logger
      @level = ::Logger::Severity.coerce(level)
    end

    # Logging severity threshold (e.g. <tt>Logger::INFO</tt>).
    def level
      local_level || @level
    end

    # Sets the log level; returns +severity+.
    #
    # Argument +severity+ may be an integer, a string, or a symbol:
    #
    #   logger.level = Logger::ERROR # => 3
    #   logger.level = 3             # => 3
    #   logger.level = 'error'       # => "error"
    #   logger.level = :error        # => :error
    def level=(severity)
      @level = ::Logger::Severity.coerce(severity)
    end

    # Closes the logger; returns +nil+:
    # Further logs won't be emitted.
    def close
      @logger = nil
    end

    # Change the underlying logger.
    def reopen(logger)
      @logger = logger
    end

    # Returns +true+ if the log level allows entries with severity
    # Logger::DEBUG to be written, +false+ otherwise.
    def debug?; level <= DEBUG; end

    # Sets the log level to Logger::DEBUG.
    def debug!; self.level = DEBUG; end

    # Returns +true+ if the log level allows entries with severity
    # Logger::INFO to be written, +false+ otherwise.
    def info?; level <= INFO; end

    # Sets the log level to Logger::INFO.
    def info!; self.level = INFO; end

    # Returns +true+ if the log level allows entries with severity
    # Logger::WARN to be written, +false+ otherwise.
    def warn?; level <= WARN; end

    # Sets the log level to Logger::WARN.
    def warn!; self.level = WARN; end

    # Returns +true+ if the log level allows entries with severity
    # Logger::ERROR to be written, +false+ otherwise.
    def error?; level <= ERROR; end

    # Sets the log level to Logger::ERROR.
    def error!; self.level = ERROR; end

    # Returns +true+ if the log level allows entries with severity
    # Logger::FATAL to be written, +false+ otherwise.
    def fatal?; level <= FATAL; end

    # Sets the log level to Logger::FATAL.
    def fatal!; self.level = FATAL; end

    # Creates a log entry, which may or may not be written to the log,
    # depending on the entry's severity and on the log level.
    #
    # Examples:
    #
    #   logger = ActiveSupport::ProxyLogger.new(Logger.new($stderr), :error)
    #   logger.add(Logger::INFO, 'Will not show')
    #   logger.add(Logger::ERROR, 'No good')
    #   logger.add(Logger::ERROR, 'No good', 'gnum')
    #
    # Output:
    #
    #   E, [2022-05-12T16:25:55.349414 #36328] ERROR -- mung: No good
    #   E, [2022-05-12T16:26:35.841134 #36328] ERROR -- gnum: No good
    #
    # These convenience methods have implicit severity:
    #
    # - #debug.
    # - #info.
    # - #warn.
    # - #error.
    # - #fatal.
    # - #unknown.
    #
    def add(severity, ...)
      severity ||= UNKNOWN
      if @logger && severity >= level
        @logger.add(severity, ...)
      else
        true
      end
    end
    alias_method :log, :add

    # Forward the given +msg+ to the underlying logger with no formatting
    # returns the number of characters written,
    # or +nil+ if the underlying logger is +nil+:
    #
    #   logger = ProxyLogger.new(Logger.new($stderr))
    #   logger << 'My message.' # => 10
    #
    # Output:
    #
    #   My message.
    #
    def <<(msg)
      if @logger
        @logger << msg
      end
    end

    # Equivalent to calling #add with severity <tt>Logger::DEBUG</tt>.
    def debug(progname = nil, &block)
      add(DEBUG, nil, progname, &block)
    end

    # Equivalent to calling #add with severity <tt>Logger::INFO</tt>.
    def info(progname = nil, &block)
      add(INFO, nil, progname, &block)
    end

    # Equivalent to calling #add with severity <tt>Logger::WARN</tt>.
    #
    def warn(progname = nil, &block)
      add(WARN, nil, progname, &block)
    end

    # Equivalent to calling #add with severity <tt>Logger::ERROR</tt>.
    #
    def error(progname = nil, &block)
      add(ERROR, nil, progname, &block)
    end

    # Equivalent to calling #add with severity <tt>Logger::FATAL</tt>.
    #
    def fatal(progname = nil, &block)
      add(FATAL, nil, progname, &block)
    end

    # Equivalent to calling #add with severity <tt>Logger::UNKNOWN</tt>.
    #
    def unknown(progname = nil, &block)
      add(UNKNOWN, nil, progname, &block)
    end
  end
end
