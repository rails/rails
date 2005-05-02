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
    remove_const "Format"
    Format = "%s\n"
    def format_message(severity, timestamp, msg, progname)
      Format % [msg]
    end
end