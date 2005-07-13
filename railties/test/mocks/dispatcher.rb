class Dispatcher
  class <<self
    attr_accessor :time_to_sleep
    attr_accessor :raise_exception
    attr_accessor :dispatch_hook

    def dispatch(cgi, session_options = nil, output = $stdout)
      dispatch_hook.call(cgi) if dispatch_hook
      sleep(time_to_sleep || 0)
      raise raise_exception, "Something died" if raise_exception
    end
  end
end
