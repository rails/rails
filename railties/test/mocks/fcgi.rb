class FCGI
  class << self
    attr_accessor :time_to_sleep
    attr_accessor :raise_exception

    def each_cgi
      sleep(time_to_sleep || 0)
      raise raise_exception, "Something died" if raise_exception
      yield "mock cgi value"
    end
  end
end
