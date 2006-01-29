require 'logger'
require File.dirname(__FILE__) + '/core_ext/class/attribute_accessors'

class Logger #:nodoc:
  cattr_accessor :silencer
  self.silencer = true

  # Silences the logger for the duration of the block.
  def silence(temporary_level = Logger::ERROR)
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

  private
    alias old_format_message format_message

    # Ruby 1.8.3 transposed the msg and progname arguments to format_message.
    # We can't test RUBY_VERSION because some distributions don't keep Ruby
    # and its standard library in sync, leading to installations of Ruby 1.8.2
    # with Logger from 1.8.3 and vice versa.
    if method_defined?(:formatter=)
      def format_message(severity, timestamp, progname, msg)
        "#{msg}\n"
      end
    else
      def format_message(severity, timestamp, msg, progname)
        "#{msg}\n"
      end
    end
end
