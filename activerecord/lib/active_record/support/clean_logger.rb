require 'logger'

class Logger #:nodoc:
  private
    remove_const "Format"
    Format = "%s\n"
    def format_message(severity, timestamp, msg, progname)
      Format % [msg]
    end
end