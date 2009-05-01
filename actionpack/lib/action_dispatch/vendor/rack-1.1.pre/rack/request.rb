require 'rack/utils'

module Rack
  # Rack::Request provides a convenient interface to a Rack
  # environment.  It is stateless, the environment +env+ passed to the
  # constructor will be directly modified.
  #
  #   req = Rack::Request.new(env)
  #   req.post?
  #   req.params["data"]
  #
  # The environment hash passed will store a reference to the Request object
  # instantiated so that it will only instantiate if an instance of the Request
  # object doesn't already exist.

  class Request
    # The environment of the request.
    attr_reader :env

    def self.new(env, *args)
      if self == Rack::Request
        env["rack.request"] ||= super
      else
        super
      end
    end

    def initialize(env)
      @env = env
    end

    def body;            @env["rack.input"]                       end
    def scheme;          @env["rack.url_scheme"]                  end
    def script_name;     @env["SCRIPT_NAME"].to_s                 end
    def path_info;       @env["PATH_INFO"].to_s                   end
    def port;            @env["SERVER_PORT"].to_i                 end
    def request_method;  @env["REQUEST_METHOD"]                   end
    def query_string;    @env["QUERY_STRING"].to_s                end
    def content_length;  @env['CONTENT_LENGTH']                   end
    def content_type;    @env['CONTENT_TYPE']                     end
    def session;         @env['rack.session'] ||= {}              end
    def session_options; @env['rack.session.options'] ||= {}      end

    # The media type (type/subtype) portion of the CONTENT_TYPE header
    # without any media type parameters. e.g., when CONTENT_TYPE is
    # "text/plain;charset=utf-8", the media-type is "text/plain".
    #
    # For more information on the use of media types in HTTP, see:
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.7
    def media_type
      content_type && content_type.split(/\s*[;,]\s*/, 2).first.downcase
    end

    # The media type parameters provided in CONTENT_TYPE as a Hash, or
    # an empty Hash if no CONTENT_TYPE or media-type parameters were
    # provided.  e.g., when the CONTENT_TYPE is "text/plain;charset=utf-8",
    # this method responds with the following Hash:
    #   { 'charset' => 'utf-8' }
    def media_type_params
      return {} if content_type.nil?
      content_type.split(/\s*[;,]\s*/)[1..-1].
        collect { |s| s.split('=', 2) }.
        inject({}) { |hash,(k,v)| hash[k.downcase] = v ; hash }
    end

    # The character set of the request body if a "charset" media type
    # parameter was given, or nil if no "charset" was specified. Note
    # that, per RFC2616, text/* media types that specify no explicit
    # charset are to be considered ISO-8859-1.
    def content_charset
      media_type_params['charset']
    end

    def host
      # Remove port number.
      (@env["HTTP_HOST"] || @env["SERVER_NAME"]).gsub(/:\d+\z/, '')
    end

    def script_name=(s); @env["SCRIPT_NAME"] = s.to_s             end
    def path_info=(s);   @env["PATH_INFO"] = s.to_s               end

    def get?;            request_method == "GET"                  end
    def post?;           request_method == "POST"                 end
    def put?;            request_method == "PUT"                  end
    def delete?;         request_method == "DELETE"               end
    def head?;           request_method == "HEAD"                 end

    # The set of form-data media-types. Requests that do not indicate
    # one of the media types presents in this list will not be eligible
    # for form-data / param parsing.
    FORM_DATA_MEDIA_TYPES = [
      nil,
      'application/x-www-form-urlencoded',
      'multipart/form-data'
    ]

    # The set of media-types. Requests that do not indicate
    # one of the media types presents in this list will not be eligible
    # for param parsing like soap attachments or generic multiparts
    PARSEABLE_DATA_MEDIA_TYPES = [
      'multipart/related',
      'multipart/mixed'
    ]  

    # Determine whether the request body contains form-data by checking
    # the request media_type against registered form-data media-types:
    # "application/x-www-form-urlencoded" and "multipart/form-data". The
    # list of form-data media types can be modified through the
    # +FORM_DATA_MEDIA_TYPES+ array.
    def form_data?
      FORM_DATA_MEDIA_TYPES.include?(media_type)
    end

    # Determine whether the request body contains data by checking
    # the request media_type against registered parse-data media-types
    def parseable_data?
      PARSEABLE_DATA_MEDIA_TYPES.include?(media_type)
    end

    # Returns the data recieved in the query string.
    def GET
      if @env["rack.request.query_string"] == query_string
        @env["rack.request.query_hash"]
      else
        @env["rack.request.query_string"] = query_string
        @env["rack.request.query_hash"]   =
          Utils.parse_nested_query(query_string)
      end
    end

    # Returns the data recieved in the request body.
    #
    # This method support both application/x-www-form-urlencoded and
    # multipart/form-data.
    def POST
      if @env["rack.request.form_input"].eql? @env["rack.input"]
        @env["rack.request.form_hash"]
      elsif form_data? || parseable_data?
        @env["rack.request.form_input"] = @env["rack.input"]
        unless @env["rack.request.form_hash"] =
            Utils::Multipart.parse_multipart(env)
          form_vars = @env["rack.input"].read

          # Fix for Safari Ajax postings that always append \0
          form_vars.sub!(/\0\z/, '')

          @env["rack.request.form_vars"] = form_vars
          @env["rack.request.form_hash"] = Utils.parse_nested_query(form_vars)

          @env["rack.input"].rewind
        end
        @env["rack.request.form_hash"]
      else
        {}
      end
    end

    # The union of GET and POST data.
    def params
      self.put? ? self.GET : self.GET.update(self.POST)
    rescue EOFError => e
      self.GET
    end

    # shortcut for request.params[key]
    def [](key)
      params[key.to_s]
    end

    # shortcut for request.params[key] = value
    def []=(key, value)
      params[key.to_s] = value
    end

    # like Hash#values_at
    def values_at(*keys)
      keys.map{|key| params[key] }
    end

    # the referer of the client or '/'
    def referer
      @env['HTTP_REFERER'] || '/'
    end
    alias referrer referer


    def cookies
      return {}  unless @env["HTTP_COOKIE"]

      if @env["rack.request.cookie_string"] == @env["HTTP_COOKIE"]
        @env["rack.request.cookie_hash"]
      else
        @env["rack.request.cookie_string"] = @env["HTTP_COOKIE"]
        # According to RFC 2109:
        #   If multiple cookies satisfy the criteria above, they are ordered in
        #   the Cookie header such that those with more specific Path attributes
        #   precede those with less specific.  Ordering with respect to other
        #   attributes (e.g., Domain) is unspecified.
        @env["rack.request.cookie_hash"] =
          Utils.parse_query(@env["rack.request.cookie_string"], ';,').inject({}) {|h,(k,v)|
            h[k] = Array === v ? v.first : v
            h
          }
      end
    end

    def xhr?
      @env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    end

    # Tries to return a remake of the original request URL as a string.
    def url
      url = scheme + "://"
      url << host

      if scheme == "https" && port != 443 ||
          scheme == "http" && port != 80
        url << ":#{port}"
      end

      url << fullpath

      url
    end
    
    def path
      script_name + path_info
    end
    
    def fullpath
      query_string.empty? ? path : "#{path}?#{query_string}"
    end

    def accept_encoding
      @env["HTTP_ACCEPT_ENCODING"].to_s.split(/,\s*/).map do |part|
        m = /^([^\s,]+?)(?:;\s*q=(\d+(?:\.\d+)?))?$/.match(part) # From WEBrick

        if m
          [m[1], (m[2] || 1.0).to_f]
        else
          raise "Invalid value for Accept-Encoding: #{part.inspect}"
        end
      end
    end

    def ip
      if addr = @env['HTTP_X_FORWARDED_FOR']
        addr.split(',').last.strip
      else
        @env['REMOTE_ADDR']
      end
    end
  end
end
