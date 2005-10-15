class Exception
  
  alias :clean_message :message
  
  TraceSubstitutions = []
  
  def clean_backtrace
    backtrace.collect do |line|
      TraceSubstitutions.inject(line) do |line, (regexp, sub)|
        line.gsub regexp, sub
      end
    end
  end
  
  def application_backtrace
    clean_backtrace.reject { |line| line =~ /(vendor|dispatch|ruby|script\/\w+)/ }
  end
end