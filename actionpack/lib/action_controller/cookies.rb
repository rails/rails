module ActionController #:nodoc:
  # Cookies are read and written through ActionController#cookies. The cookies being read is what was received along with the request,
  # the cookies being written is what will be sent out will the response. Cookies are read by value (so you won't get the cookie object
  # itself back -- just the value it holds). Examples for writting:
  #
  #   cookies["user_name"] = "david" # => Will set a simple session cookie
  #   cookies["login"] = { :value => "XJ-122", :expires => Time.now + 360} # => Will set a cookie that expires in 1 hour
  #   
  # Examples for reading:
  #
  #   cookies["user_name"] # => "david"
  #   cookies.size         # => 2
  # 
  # Example for deleting:
  #
  #   cookies.delete "user_name"
  #
  # All the option symbols for setting cookies are:
  #
  # * <tt>value</tt> - the cookie's value or list of values (as an array).
  # * <tt>path</tt> - the path for which this cookie applies.  Defaults to the root of the application.
  # * <tt>domain</tt> - the domain for which this cookie applies.
  # * <tt>expires</tt> - the time at which this cookie expires, as a +Time+ object.
  # * <tt>secure</tt> - whether this cookie is a secure cookie or not (default to false).
  #   Secure cookies are only transmitted to HTTPS servers.
  module Cookies
    # Returns the cookie container, which operates as described above.
    def cookies
      CookieJar.new(self)
    end
  end
  
  class CookieJar < Hash #:nodoc:
    def initialize(controller)
      @controller, @cookies = controller, controller.instance_variable_get("@cookies")
      super()
      update(@cookies)
    end

    # Returns the value of the cookie by +name+ -- or nil if no such cookie exist. You set new cookies using either the cookie method
    # or cookies[]= (for simple name/value cookies without options).
    def [](name)
      @cookies[name.to_s].value.first if @cookies[name.to_s] && @cookies[name.to_s].respond_to?(:value)
    end
    
    def []=(name, options)
      if options.is_a?(Hash)
        options = options.inject({}) { |options, pair| options[pair.first.to_s] = pair.last; options }
        options["name"] = name.to_s
      else
        options = { "name" => name.to_s, "value" => options }
      end
      
      set_cookie(options)
    end
    
    # Removes the cookie on the client machine by setting the value to an empty string.
    def delete(name)
      set_cookie("name" => name.to_s, "value" => "")
    end

    private
      def set_cookie(options) #:doc:
        options["path"] = "/" unless options["path"]
        cookie = CGI::Cookie.new(options)
        @controller.logger.info "Cookie set: #{cookie}" unless @controller.logger.nil?
        @controller.response.headers["cookie"] << cookie
      end
  end
end
