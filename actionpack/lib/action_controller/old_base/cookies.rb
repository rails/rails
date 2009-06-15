module ActionController #:nodoc:
  # Cookies are read and written through ActionController#cookies.
  #
  # The cookies being read are the ones received along with the request, the cookies
  # being written will be sent out with the response. Reading a cookie does not get
  # the cookie object itself back, just the value it holds.
  #
  # Examples for writing:
  #
  #   # Sets a simple session cookie.
  #   cookies[:user_name] = "david"
  #
  #   # Sets a cookie that expires in 1 hour.
  #   cookies[:login] = { :value => "XJ-122", :expires => 1.hour.from_now }
  #
  # Examples for reading:
  #
  #   cookies[:user_name] # => "david"
  #   cookies.size        # => 2
  #
  # Example for deleting:
  #
  #   cookies.delete :user_name
  #
  # Please note that if you specify a :domain when setting a cookie, you must also specify the domain when deleting the cookie:
  #
  #  cookies[:key] = {
  #    :value => 'a yummy cookie',
  #    :expires => 1.year.from_now,
  #    :domain => 'domain.com'
  #  }
  #
  #  cookies.delete(:key, :domain => 'domain.com')
  #
  # The option symbols for setting cookies are:
  #
  # * <tt>:value</tt> - The cookie's value or list of values (as an array).
  # * <tt>:path</tt> - The path for which this cookie applies.  Defaults to the root
  #   of the application.
  # * <tt>:domain</tt> - The domain for which this cookie applies.
  # * <tt>:expires</tt> - The time at which this cookie expires, as a Time object.
  # * <tt>:secure</tt> - Whether this cookie is a only transmitted to HTTPS servers.
  #   Default is +false+.
  # * <tt>:httponly</tt> - Whether this cookie is accessible via scripting or
  #   only HTTP. Defaults to +false+.
  module Cookies
    def self.included(base)
      base.helper_method :cookies
    end

    protected
      # Returns the cookie container, which operates as described above.
      def cookies
        @cookies ||= CookieJar.new(self)
      end
  end

  class CookieJar < Hash #:nodoc:
    def initialize(controller)
      @controller, @cookies = controller, controller.request.cookies
      super()
      update(@cookies)
    end

    # Returns the value of the cookie by +name+, or +nil+ if no such cookie exists.
    def [](name)
      super(name.to_s)
    end

    # Sets the cookie named +name+. The second argument may be the very cookie
    # value, or a hash of options as documented above.
    def []=(key, options)
      if options.is_a?(Hash)
        options.symbolize_keys!
      else
        options = { :value => options }
      end

      options[:path] = "/" unless options.has_key?(:path)
      super(key.to_s, options[:value])
      @controller.response.set_cookie(key, options)
    end

    # Removes the cookie on the client machine by setting the value to an empty string
    # and setting its expiration date into the past. Like <tt>[]=</tt>, you can pass in
    # an options hash to delete cookies with extra data such as a <tt>:path</tt>.
    def delete(key, options = {})
      options.symbolize_keys!
      options[:path] = "/" unless options.has_key?(:path)
      super(key.to_s)
      @controller.response.delete_cookie(key, options)
    end
  end
end
