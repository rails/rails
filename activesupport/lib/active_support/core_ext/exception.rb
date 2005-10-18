class Exception
  
  alias :clean_message :message
  
  TraceSubstitutions = []
  FrameworkRegexp = /generated_code|vendor|dispatch|ruby|script\/\w+/
  
  def clean_backtrace
    backtrace.collect do |line|
      TraceSubstitutions.inject(line) do |line, (regexp, sub)|
        line.gsub regexp, sub
      end
    end
  end
  
  def application_backtrace
    before_application_frame = true
    
    clean_backtrace.reject do |line|
      non_app_frame = !! (line =~ FrameworkRegexp)
      before_application_frame = false unless non_app_frame
      non_app_frame && ! before_application_frame
    end
  end
  
  def framework_backtrace
    clean_backtrace.select {|line| line =~ FrameworkRegexp}
  end
end