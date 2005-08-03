module SwitchTower
  class Logger #:nodoc:
    attr_accessor :level

    IMPORTANT = 0
    INFO      = 1
    DEBUG     = 2
    TRACE     = 3

    def initialize(options={})
      output = options[:output] || STDERR
      case
        when output.respond_to?(:puts)
          @device = output
        else
          @device = File.open(output.to_str, "a")
          @needs_close = true
      end

      @options = options
      @level = 0
    end

    def close
      @device.close if @needs_close
    end

    def log(level, message, line_prefix=nil)
      if level <= self.level
        if line_prefix
          message.split(/\r?\n/).each do |line|
            @device.print "[#{line_prefix}] #{line.strip}\n"
          end
        else
          @device.puts message.strip
        end
      end
    end

    def important(message, line_prefix=nil)
      log(IMPORTANT, message, line_prefix)
    end

    def info(message, line_prefix=nil)
      log(INFO, message, line_prefix)
    end

    def debug(message, line_prefix=nil)
      log(DEBUG, message, line_prefix)
    end

    def trace(message, line_prefix=nil)
      log(TRACE, message, line_prefix)
    end
  end
end
