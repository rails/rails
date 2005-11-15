CGI.module_eval { remove_const "Cookie" }

class CGI #:nodoc:
  # This is a cookie class that fixes the performance problems with the default one that ships with 1.8.1 and below.
  # It replaces the inheritance on SimpleDelegator with DelegateClass(Array) following the suggestion from Matz on
  # http://groups.google.com/groups?th=e3a4e68ba042f842&seekm=c3sioe%241qvm%241%40news.cybercity.dk#link14
  class Cookie < DelegateClass(Array)
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
    #
    # These keywords correspond to attributes of the cookie object.
    def initialize(name = '', *value)
      if name.kind_of?(String)
        @name = name
        @value = Array(value)
        @domain = nil
        @expires = nil
        @secure = false
        @path = nil
      else
        @name = name['name']
        @value = Array(name['value'])
        @domain = name['domain']
        @expires = name['expires']
        @secure = name['secure'] || false
        @path = name['path']
      end
      
      unless @name
        raise ArgumentError, "`name' required"
      end

      # simple support for IE
      unless @path
        %r|^(.*/)|.match(ENV['SCRIPT_NAME'])
        @path = ($1 or '')
      end

      super(@value)
    end

    def __setobj__(obj)
      @_dc_obj = obj
    end

    attr_accessor("name", "value", "path", "domain", "expires")
    attr_reader("secure")

    # Set whether the Cookie is a secure cookie or not.
    #
    # +val+ must be a boolean.
    def secure=(val)
      @secure = val if val == true or val == false
      @secure
    end

    # Convert the Cookie to its string representation.
    def to_s
      buf = ""
      buf << @name << '='

      if @value.kind_of?(String)
        buf << CGI::escape(@value)
      else
        buf << @value.collect{|v| CGI::escape(v) }.join("&")
      end

      if @domain
        buf << '; domain=' << @domain
      end

      if @path
        buf << '; path=' << @path
      end

      if @expires
        buf << '; expires=' << CGI::rfc1123_date(@expires)
      end

      if @secure == true
        buf << '; secure'
      end

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
        raw_cookie.split(/; ?/).each do |pairs|
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
