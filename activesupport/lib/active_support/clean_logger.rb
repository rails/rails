require 'logger'

class Logger #:nodoc:
  # Silences the logger for the duration of the block.
  def silence
    result = nil
    old_logger_level = level
    self.level = Logger::ERROR
    result = yield
    self.level = old_logger_level
    return result
  end

  private
    remove_const "Format"
    Format = "%s\n"
    def format_message(severity, timestamp, msg, progname)
      Format % [msg]
    end
end