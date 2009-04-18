module ActiveSupport
  FrozenObjectError = RUBY_VERSION < '1.9' ? TypeError : RuntimeError
end

# TODO: Turn all this into using the BacktraceCleaner.
class Exception # :nodoc:
  # Clean the paths contained in the message.
  def self.clean_paths(string)
    require 'pathname' unless defined? Pathname
    string.gsub(%r{[\w. ]+(/[\w. ]+)+(\.rb)?(\b|$)}) do |path|
      Pathname.new(path).cleanpath
    end
  end

  def clean_message
    Exception.clean_paths(message)
  end

  TraceSubstitutions = []
  FrameworkStart = /action_controller\/dispatcher\.rb/.freeze
  FrameworkRegexp = /generated|vendor|dispatch|ruby|script\/\w+/.freeze

  def clean_backtrace
    backtrace.collect do |line|
      substituted = TraceSubstitutions.inject(line) do |result, (regexp, sub)|
        result.gsub regexp, sub
      end
      Exception.clean_paths(substituted)
    end
  end

  def application_backtrace
    before_framework_frame = nil
    before_application_frame = true

    trace = clean_backtrace.reject do |line|
      before_framework_frame ||= (line =~ FrameworkStart)
      non_app_frame = (line =~ FrameworkRegexp)
      before_application_frame = false unless non_app_frame
      before_framework_frame || (non_app_frame && !before_application_frame)
    end

    # If we didn't find any application frames, return an empty app trace.
    before_application_frame ? [] : trace
  end

  def framework_backtrace
    clean_backtrace.grep FrameworkRegexp
  end
end
