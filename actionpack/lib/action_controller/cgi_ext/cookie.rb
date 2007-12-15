CGI.module_eval { remove_const "Cookie" }

# TODO: document how this differs from stdlib CGI::Cookie
class CGI #:nodoc:
  class Cookie < DelegateClass(Array)
    attr_accessor :name, :value, :path, :domain, :expires
    attr_reader :secure, :http_only

    # Create a new CGI::Cookie object.
    #
    # The contents of the cookie can be specified as a +name+ and one
    # or more +value+ arguments.  Alternatively, the contents can
    # be specified as a single hash argument.  The possible keywords of
    # this hash are as follows:
    #
    # name:: the name of the cookie.  Required.
    # value:: the cookie's value or list of values.
    # path:: the path for which this cookie applies.  Defaults to the
    #        base directory of the CGI script.
    # domain:: the domain for which this cookie applies.
    # expires:: the time at which this cookie expires, as a +Time+ object.
    # secure:: whether this cookie is a secure cookie or not (default to
    #          false).  Secure cookies are only transmitted to HTTPS
    #          servers.
    # http_only:: whether this cookie can be accessed by client side scripts (e.g. document.cookie) or only over HTTP 
    #             More details: http://msdn2.microsoft.com/en-us/library/system.web.httpcookie.httponly.aspx
    #             Defaults to false.
    # These keywords correspond to attributes of the cookie object.
    def initialize(name = '', *value)
      if name.kind_of?(String)
        @name = name
        @value = Array(value)
        @domain = nil
        @expires = nil
        @secure = false
        @http_only = false
        @path = nil
      else
        @name = name['name']
        @value = Array(name['value'])
        @domain = name['domain']
        @expires = name['expires']
        @secure = name['secure'] || false
        @http_only = name['http_only'] || false
        @path = name['path']
      end

      raise ArgumentError, "`name' required" unless @name

      # simple support for IE
      unless @path
        %r|^(.*/)|.match(ENV['SCRIPT_NAME'])
        @path = ($1 or '')
      end

      super(@value)
    end

    # Set whether the Cookie is a secure cookie or not.
    def secure=(val)
      @secure = val == true
    end

    # Set whether the Cookie is an HTTP only cookie or not.
    def http_only=(val)
      @http_only = val == true
    end

    # Convert the Cookie to its string representation.
    def to_s
      buf = ''
      buf << @name << '='
      buf << (@value.kind_of?(String) ? CGI::escape(@value) : @value.collect{|v| CGI::escape(v) }.join("&"))
      buf << '; domain=' << @domain if @domain
      buf << '; path=' << @path if @path
      buf << '; expires=' << CGI::rfc1123_date(@expires) if @expires
      buf << '; secure' if @secure
      buf << '; HttpOnly' if @http_only
      buf
    end

    # Parse a raw cookie string into a hash of cookie-name=>Cookie
    # pairs.
    #
    #   cookies = CGI::Cookie::parse("raw_cookie_string")
    #     # { "name1" => cookie1, "name2" => cookie2, ... }
    #
    def self.parse(raw_cookie)
      cookies = Hash.new([])

      if raw_cookie
        raw_cookie.split(/[;,]\s?/).each do |pairs|
          name, values = pairs.split('=',2)
          next unless name and values
          name = CGI::unescape(name)
          values = values.split('&').collect!{|v| CGI::unescape(v) }
          unless cookies.has_key?(name)
            cookies[name] = new(name, *values)
          end
        end
      end

      cookies
    end
  end # class Cookie
end
