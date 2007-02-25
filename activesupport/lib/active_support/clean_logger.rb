require 'logger'
require File.dirname(__FILE__) + '/core_ext/class/attribute_accessors'

# Extensions to the built in Ruby logger.
#
# If you want to use the default log formatter as defined in the Ruby core, then you 
# will need to set the formatter for the logger as in:
#
#   logger.formatter = Formatter.new
#
# You can then specify the datetime format, for example:
#
#   logger.datetime_format = "%Y-%m-%d"
class Logger
  # Set to false to disable the silencer
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
  
  alias :old_datetime_format= :datetime_format=
  # Logging date-time format (string passed to +strftime+). Ignored if the formatter
  # does not respond to datetime_format=.
  def datetime_format=(datetime_format)
    formatter.datetime_format = datetime_format if formatter.respond_to?(:datetime_format=)
  end
  
  alias :old_datetime_format :datetime_format
  # Get the logging datetime format. Returns nil if the formatter does not support
  # datetime formatting.
  def datetime_format
    formatter.datetime_format if formatter.respond_to?(:datetime_format)
  end
  
  alias :old_formatter :formatter
  # Get the current formatter. The default formatter is a SimpleFormatter which only
  # displays the log message
  def formatter
    @formatter ||= SimpleFormatter.new
  end
  
  # Simple formatter which only displays the message.
  class SimpleFormatter < Logger::Formatter
    # This method is invoked when a log event occurs
    def call(severity, timestamp, progname, msg)
      "#{msg}\n"
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
        formatter.call(severity, timestamp, progname, msg)
      end
    else
      def format_message(severity, timestamp, msg, progname)
        formatter.call(severity, timestamp, progname, msg)
      end
    end
end
