module ActiveSupport
  if RUBY_VERSION >= '1.9'
    FrozenObjectError = RuntimeError
  else
    FrozenObjectError = TypeError
  end
end

class Exception # :nodoc:
  def clean_message
    Pathname.clean_within message
  end
  
  TraceSubstitutions = []
  FrameworkRegexp = /generated|vendor|dispatch|ruby|script\/\w+/
  
  def clean_backtrace
    backtrace.collect do |line|
      Pathname.clean_within(TraceSubstitutions.inject(line) do |result, (regexp, sub)|
        result.gsub regexp, sub
      end)
    end
  end
  
  def application_backtrace
    before_application_frame = true
    
    trace = clean_backtrace.reject do |line|
      non_app_frame = (line =~ FrameworkRegexp)
      before_application_frame = false unless non_app_frame
      non_app_frame && ! before_application_frame
    end
    
    # If we didn't find any application frames, return an empty app trace.
    before_application_frame ? [] : trace
  end
  
  def framework_backtrace
    clean_backtrace.grep FrameworkRegexp
  end
end
