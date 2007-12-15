module ActionController #:nodoc:
  # Cookies are read and written through ActionController#cookies. The cookies being read are what were received along with the request,
  # the cookies being written are what will be sent out with the response. Cookies are read by value (so you won't get the cookie object
  # itself back -- just the value it holds). Examples for writing:
  #
  #   cookies[:user_name] = "david" # => Will set a simple session cookie
  #   cookies[:login] = { :value => "XJ-122", :expires => 1.hour.from_now }
  #   # => Will set a cookie that expires in 1 hour
  #
  # Examples for reading:
  #
  #   cookies[:user_name] # => "david"
  #   cookies.size         # => 2
  #
  # Example for deleting:
  #
  #   cookies.delete :user_name
  #
  # All the option symbols for setting cookies are:
  #
  # * <tt>value</tt> - the cookie's value or list of values (as an array).
  # * <tt>path</tt> - the path for which this cookie applies.  Defaults to the root of the application.
  # * <tt>domain</tt> - the domain for which this cookie applies.
  # * <tt>expires</tt> - the time at which this cookie expires, as a +Time+ object.
  # * <tt>secure</tt> - whether this cookie is a secure cookie or not (default to false).
  #                     Secure cookies are only transmitted to HTTPS servers.
  # * <tt>http_only</tt> - whether this cookie is accessible via scripting or only HTTP (defaults to false).
  
  module Cookies
    def self.included(base)
      base.helper_method :cookies
    end

    protected
      # Returns the cookie container, which operates as described above.
      def cookies
        CookieJar.new(self)
      end
  end

  class CookieJar < Hash #:nodoc:
    def initialize(controller)
      @controller, @cookies = controller, controller.request.cookies
      super()
      update(@cookies)
    end

    # Returns the value of the cookie by +name+ -- or nil if no such cookie exists. You set new cookies using cookies[]=
    # (for simple name/value cookies without options).
    def [](name)
      cookie = @cookies[name.to_s]
      if cookie && cookie.respond_to?(:value)
        cookie.size > 1 ? cookie.value : cookie.value[0]
      end
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

    # Removes the cookie on the client machine by setting the value to an empty string
    # and setting its expiration date into the past.  Like []=, you can pass in an options
    # hash to delete cookies with extra data such as a +path+.
    def delete(name, options = {})
      options.stringify_keys!
      set_cookie(options.merge("name" => name.to_s, "value" => "", "expires" => Time.at(0)))
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
