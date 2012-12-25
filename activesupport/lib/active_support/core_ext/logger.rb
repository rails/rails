require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/deprecation'
require 'active_support/logger_silence'

ActiveSupport::Deprecation.warn 'this file is deprecated and will be removed'

# Adds the 'around_level' method to Logger.
class Logger #:nodoc:
  def self.define_around_helper(level)
    module_eval <<-end_eval, __FILE__, __LINE__ + 1
      def around_#{level}(before_message, after_message)  # def around_debug(before_message, after_message, &block)
        self.#{level}(before_message)                     #   self.debug(before_message)
        return_value = yield(self)                        #   return_value = yield(self)
        self.#{level}(after_message)                      #   self.debug(after_message)
        return_value                                      #   return_value
      end                                                 # end
    end_eval
  end
  [:debug, :info, :error, :fatal].each {|level| define_around_helper(level) }
end

require 'logger'

# Extensions to the built-in Ruby logger.
#
# If you want to use the default log formatter as defined in the Ruby core, then you
# will need to set the formatter for the logger as in:
#
#   logger.formatter = Formatter.new
#
# You can then specify the datetime format, for example:
#
#   logger.datetime_format = "%Y-%m-%d"
#
# Note: This logger is deprecated in favor of ActiveSupport::Logger
class Logger
  include LoggerSilence

  alias :old_datetime_format= :datetime_format=
  # Logging date-time format (string passed to +strftime+). Ignored if the formatter
  # does not respond to datetime_format=.
  def datetime_format=(format)
    formatter.datetime_format = format if formatter.respond_to?(:datetime_format=)
  end

  alias :old_datetime_format :datetime_format
  # Get the logging datetime format. Returns nil if the formatter does not support
  # datetime formatting.
  def datetime_format
    formatter.datetime_format if formatter.respond_to?(:datetime_format)
  end

  alias :old_initialize :initialize
  # Overwrite initialize to set a default formatter.
  def initialize(*args)
    old_initialize(*args)
    self.formatter = SimpleFormatter.new
  end

  # Simple formatter which only displays the message.
  class SimpleFormatter < Logger::Formatter
    # This method is invoked when a log event occurs
    def call(severity, timestamp, progname, msg)
      "#{String === msg ? msg : msg.inspect}\n"
    end
  end
end
