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

    # Set to false to disable the silencer
    cattr_accessor :silencer
    self.silencer = true

    # Silences the logger for the duration of the block.
    def silence(temporary_level = ERROR)
      if silencer
        begin
          old_logger_level, self.level = level, temporary_level
          yield self
        ensure
          self.level = old_logger_level
        end
      else
        yield self
      end
    end

    attr_accessor :level, :auto_flushing
    attr_reader :buffer

    def initialize(log, level = DEBUG)
      @level         = level
      @buffer        = ""
      @auto_flushing = true

      if log.respond_to?(:write)
        @log = log
      elsif File.exist?(log)
        @log = open(log, (File::WRONLY | File::APPEND))
        @log.sync = true
      else
        @log = open(log, (File::WRONLY | File::APPEND | File::CREAT))
        @log.sync = true
        @log.write("# Logfile created on %s" % [Time.now.to_s])
      end
    end

    def add(severity, message = nil, progname = nil, &block)
      return if @level > severity
      message = (message || (block && block.call) || progname).to_s
      # If a newline is necessary then create a new message ending with a newline.
      # Ensures that the original message is not mutated.
      message = "#{message}\n" unless message[-1] == ?\n
      @buffer << message
      flush if auto_flushing
      message
    end

    for severity in Severity.constants
      class_eval <<-EOT
        def #{severity.downcase}(message = nil, progname = nil, &block)
          add(#{severity}, message, progname, &block)
        end
        
        def #{severity.downcase}?
          @level == #{severity}
        end
      EOT
    end

    def flush
      return if @buffer.size == 0
      @log.write(@buffer.slice!(0..-1))
    end

    def close
      flush
      @log.close if @log.respond_to?(:close)
      @log = nil
    end
  end
end