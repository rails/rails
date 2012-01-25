require 'thread'
require 'logger'
require 'active_support/core_ext/logger'
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/deprecation'
require 'fileutils'

module ActiveSupport
  # Inspired by the buffered logger idea by Ezra
  class BufferedLogger
    module Severity
      DEBUG   = 0
      INFO    = 1
      WARN    = 2
      ERROR   = 3
      FATAL   = 4
      UNKNOWN = 5
    end
    include Severity

    MAX_BUFFER_SIZE = 1000

    ##
    # :singleton-method:
    # Set to false to disable the silencer
    cattr_accessor :silencer
    self.silencer = true

    # Silences the logger for the duration of the block.
    def silence(temporary_level = ERROR)
      if silencer
        begin
          logger = self.class.new @log_dest.dup, temporary_level
          yield logger
        ensure
          logger.close
        end
      else
        yield self
      end
    end
    deprecate :silence

    attr_reader :auto_flushing
    deprecate :auto_flushing

    def initialize(log, level = DEBUG)
      @level         = level
      @log_dest      = log

      unless log.respond_to?(:write)
        unless File.exist?(File.dirname(log))
          ActiveSupport::Deprecation.warn(<<-eowarn)
Automatic directory creation for '#{log}' is deprecated.  Please make sure the directory for your log file exists before creating the logger.
          eowarn
          FileUtils.mkdir_p(File.dirname(log))
        end
      end

      @log = open_logfile log
    end

    def open_log(log, mode)
      open(log, mode).tap do |open_log|
        open_log.set_encoding(Encoding::BINARY) if open_log.respond_to?(:set_encoding)
        open_log.sync = true
      end
    end
    deprecate :open_log

    def level
      @log.level
    end

    def level=(l)
      @log.level = l
    end

    def add(severity, message = nil, progname = nil, &block)
      @log.add(severity, message, progname, &block)
    end

    # Dynamically add methods such as:
    # def info
    # def warn
    # def debug
    Severity.constants.each do |severity|
      class_eval <<-EOT, __FILE__, __LINE__ + 1
        def #{severity.downcase}(message = nil, progname = nil, &block) # def debug(message = nil, progname = nil, &block)
          add(#{severity}, message, progname, &block)                   #   add(DEBUG, message, progname, &block)
        end                                                             # end

        def #{severity.downcase}?                                       # def debug?
          #{severity} >= level                                         #   DEBUG >= @level
        end                                                             # end
      EOT
    end

    # Set the auto-flush period. Set to true to flush after every log message,
    # to an integer to flush every N messages, or to false, nil, or zero to
    # never auto-flush. If you turn auto-flushing off, be sure to regularly
    # flush the log yourself -- it will eat up memory until you do.
    def auto_flushing=(period)
    end
    deprecate :auto_flushing=

    def flush
    end
    deprecate :flush

    def respond_to?(method, include_private = false)
      return false if method.to_s == "flush"
      super
    end

    def close
      @log.close
    end

    private
    def open_logfile(log)
      Logger.new log
    end
  end
end
