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
      base.cattr_accessor :cookie_verifier_secret
    end

    protected
      # Returns the cookie container, which operates as described above.
      def cookies
        @cookies ||= CookieJar.new(self)
      end
  end

  class CookieJar < Hash #:nodoc:
    attr_reader :controller
    
    def initialize(controller)
      @controller, @cookies, @secure = controller, controller.request.cookies, controller.request.ssl?
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
      @controller.response.set_cookie(key, options) if write_cookie?(options)
    end

    # Removes the cookie on the client machine by setting the value to an empty string
    # and setting its expiration date into the past. Like <tt>[]=</tt>, you can pass in
    # an options hash to delete cookies with extra data such as a <tt>:path</tt>.
    def delete(key, options = {})
      options.symbolize_keys!
      options[:path] = "/" unless options.has_key?(:path)
      value = super(key.to_s)
      @controller.response.delete_cookie(key, options)
      value
    end

    # Returns a jar that'll automatically set the assigned cookies to have an expiration date 20 years from now. Example:
    #
    #   cookies.permanent[:prefers_open_id] = true
    #   # => Set-Cookie: prefers_open_id=true; path=/; expires=Sun, 16-Dec-2029 03:24:16 GMT
    #
    # This jar is only meant for writing. You'll read permanent cookies through the regular accessor.
    #
    # This jar allows chaining with the signed jar as well, so you can set permanent, signed cookies. Examples:
    #
    #   cookies.permanent.signed[:remember_me] = current_user.id
    #   # => Set-Cookie: discount=BAhU--848956038e692d7046deab32b7131856ab20e14e; path=/; expires=Sun, 16-Dec-2029 03:24:16 GMT
    def permanent
      @permanent ||= PermanentCookieJar.new(self)
    end
    
    # Returns a jar that'll automatically generate a signed representation of cookie value and verify it when reading from
    # the cookie again. This is useful for creating cookies with values that the user is not supposed to change. If a signed
    # cookie was tampered with by the user (or a 3rd party), an ActiveSupport::MessageVerifier::InvalidSignature exception will
    # be raised.
    #
    # This jar requires that you set a suitable secret for the verification on ActionController::Base.cookie_verifier_secret.
    #
    # Example:
    #
    #   cookies.signed[:discount] = 45
    #   # => Set-Cookie: discount=BAhpMg==--2c1c6906c90a3bc4fd54a51ffb41dffa4bf6b5f7; path=/
    #
    #   cookies.signed[:discount] # => 45
    def signed
      @signed ||= SignedCookieJar.new(self)
    end

    private

      def write_cookie?(cookie)
        @secure || !cookie[:secure] || defined?(Rails.env) && Rails.env.development?
      end
  end
  
  class PermanentCookieJar < CookieJar #:nodoc:
    def initialize(parent_jar)
      @parent_jar = parent_jar
    end

    def []=(key, options)
      if options.is_a?(Hash)
        options.symbolize_keys!
      else
        options = { :value => options }
      end
      
      options[:expires] = 20.years.from_now
      @parent_jar[key] = options
    end

    def signed
      @signed ||= SignedCookieJar.new(self)
    end

    def controller
      @parent_jar.controller
    end

    def method_missing(method, *arguments, &block)
      @parent_jar.send(method, *arguments, &block)
    end
  end
  
  class SignedCookieJar < CookieJar #:nodoc:
    def initialize(parent_jar)
      unless parent_jar.controller.class.cookie_verifier_secret
        raise "You must set ActionController::Base.cookie_verifier_secret to use signed cookies"
      end

      @parent_jar = parent_jar
      @verifier = ActiveSupport::MessageVerifier.new(@parent_jar.controller.class.cookie_verifier_secret)
    end
    
    def [](name)
      if value = @parent_jar[name]
        @verifier.verify(value)
      end
    end
    
    def []=(key, options)
      if options.is_a?(Hash)
        options.symbolize_keys!
        options[:value] = @verifier.generate(options[:value])
      else
        options = { :value => @verifier.generate(options) }
      end
      
      @parent_jar[key] = options
    end
    
    def method_missing(method, *arguments, &block)
      @parent_jar.send(method, *arguments, &block)
    end
  end
end
