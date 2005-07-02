class FCGI
  class << self
    attr_accessor :time_to_sleep
    attr_accessor :raise_exception
    attr_accessor :each_cgi_count

    def each_cgi
      (each_cgi_count || 1).times do
        sleep(time_to_sleep || 0)
        raise raise_exception, "Something died" if raise_exception
        yield "mock cgi value"
      end
    end
  end
end
