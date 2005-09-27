require 'logger'

class Logger #:nodoc:
  # Silences the logger for the duration of the block.
  def silence(temporary_level = Logger::ERROR)
    old_logger_level, self.level = level, temporary_level
    yield
  ensure
    self.level = old_logger_level
  end

  private
    # Ruby 1.8.3 swapped the format_message params.
    if RUBY_VERSION < '1.8.3'
      def format_message(severity, timestamp, msg, progname)
        "#{msg}\n"
      end
    else
      def format_message(severity, timestamp, progname, msg)
        "#{msg}\n"
      end
    end
end
