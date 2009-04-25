require 'tempfile'
require 'stringio'
require 'strscan'

require 'active_support/memoizable'
require 'action_controller/cgi_ext'

module ActionController
  class Request < Rack::Request

    %w[ AUTH_TYPE GATEWAY_INTERFACE
        PATH_TRANSLATED REMOTE_HOST
        REMOTE_IDENT REMOTE_USER REMOTE_ADDR
        SERVER_NAME SERVER_PROTOCOL

        HTTP_ACCEPT HTTP_ACCEPT_CHARSET HTTP_ACCEPT_ENCODING
        HTTP_ACCEPT_LANGUAGE HTTP_CACHE_CONTROL HTTP_FROM
        HTTP_NEGOTIATE HTTP_PRAGMA HTTP_REFERER HTTP_USER_AGENT ].each do |env|
      define_method(env.sub(/^HTTP_/n, '').downcase) do
        @env[env]
      end
    end

    def key?(key)
      @env.key?(key)
    end

    HTTP_METHODS = %w(get head put post delete options)
    HTTP_METHOD_LOOKUP = HTTP_METHODS.inject({}) { |h, m| h[m] = h[m.upcase] = m.to_sym; h }

    # Returns the true HTTP request \method as a lowercase symbol, such as
    # <tt>:get</tt>. If the request \method is not listed in the HTTP_METHODS
    # constant above, an UnknownHttpMethod exception is raised.
    def request_method
      @request_method ||= HTTP_METHOD_LOOKUP[super] || raise(UnknownHttpMethod, "#{super}, accepted HTTP methods are #{HTTP_METHODS.to_sentence(:locale => :en)}")
    end

    # Returns the HTTP request \method used for action processing as a
    # lowercase symbol, such as <tt>:post</tt>. (Unlike #request_method, this
    # method returns <tt>:get</tt> for a HEAD request because the two are
    # functionally equivalent from the application's perspective.)
    def method
      request_method == :head ? :get : request_method
    end

    # Is this a GET (or HEAD) request?  Equivalent to <tt>request.method == :get</tt>.
    def get?
      method == :get
    end

    # Is this a POST request?  Equivalent to <tt>request.method == :post</tt>.
    def post?
      request_method == :post
    end

    # Is this a PUT request?  Equivalent to <tt>request.method == :put</tt>.
    def put?
      request_method == :put
    end

    # Is this a DELETE request?  Equivalent to <tt>request.method == :delete</tt>.
    def delete?
      request_method == :delete
    end

    # Is this a HEAD request? Since <tt>request.method</tt> sees HEAD as <tt>:get</tt>,
    # this \method checks the actual HTTP \method directly.
    def head?
      request_method == :head
    end

    # Provides access to the request's HTTP headers, for example:
    #
    #   request.headers["Content-Type"] # => "text/plain"
    def headers
      @headers ||= ActionController::Http::Headers.new(@env)
    end

    # Returns the content length of the request as an integer.
    def content_length
      super.to_i
    end

    # The MIME type of the HTTP request, such as Mime::XML.
    #
    # For backward compatibility, the post \format is extracted from the
    # X-Post-Data-Format HTTP header if present.
    def content_type
      @content_type ||= begin
        if @env['CONTENT_TYPE'] =~ /^([^,\;]*)/
          Mime::Type.lookup($1.strip.downcase)
        else
          nil
        end
      end
    end

    def media_type
      content_type.to_s
    end

    # Returns the accepted MIME type for the request.
    def accepts
      @accepts ||= begin
        header = @env['HTTP_ACCEPT'].to_s.strip

        if header.empty?
          [content_type, Mime::ALL].compact
        else
          Mime::Type.parse(header)
        end
      end
    end

    def if_modified_since
      if since = env['HTTP_IF_MODIFIED_SINCE']
        Time.rfc2822(since) rescue nil
      end
    end

    def if_none_match
      env['HTTP_IF_NONE_MATCH']
    end

    def not_modified?(modified_at)
      if_modified_since && modified_at && if_modified_since >= modified_at
    end

    def etag_matches?(etag)
      if_none_match && if_none_match == etag
    end

    # Check response freshness (Last-Modified and ETag) against request
    # If-Modified-Since and If-None-Match conditions. If both headers are
    # supplied, both must match, or the request is not considered fresh.
    def fresh?(response)
      case
      when if_modified_since && if_none_match
        not_modified?(response.last_modified) && etag_matches?(response.etag)
      when if_modified_since
        not_modified?(response.last_modified)
      when if_none_match
        etag_matches?(response.etag)
      else
        false
      end
    end

    # Returns the Mime type for the \format used in the request.
    #
    #   GET /posts/5.xml   | request.format => Mime::XML
    #   GET /posts/5.xhtml | request.format => Mime::HTML
    #   GET /posts/5       | request.format => Mime::HTML or MIME::JS, or request.accepts.first depending on the value of <tt>ActionController::Base.use_accept_header</tt>
    def format
      @format ||=
        if parameters[:format]
          Mime::Type.lookup_by_extension(parameters[:format])
        elsif ActionController::Base.use_accept_header
          accepts.first
        elsif xhr?
          Mime::Type.lookup_by_extension("js")
        else
          Mime::Type.lookup_by_extension("html")
        end
    end


    # Sets the \format by string extension, which can be used to force custom formats
    # that are not controlled by the extension.
    #
    #   class ApplicationController < ActionController::Base
    #     before_filter :adjust_format_for_iphone
    #
    #     private
    #       def adjust_format_for_iphone
    #         request.format = :iphone if request.env["HTTP_USER_AGENT"][/iPhone/]
    #       end
    #   end
    def format=(extension)
      parameters[:format] = extension.to_s
      @format = Mime::Type.lookup_by_extension(parameters[:format])
    end

    # Returns a symbolized version of the <tt>:format</tt> parameter of the request.
    # If no \format is given it returns <tt>:js</tt>for Ajax requests and <tt>:html</tt>
    # otherwise.
    def template_format
      parameter_format = parameters[:format]

      if parameter_format
        parameter_format
      elsif xhr?
        :js
      else
        :html
      end
    end

    def cache_format
      parameters[:format]
    end

    # Returns true if the request's "X-Requested-With" header contains
    # "XMLHttpRequest". (The Prototype Javascript library sends this header with
    # every Ajax request.)
    def xml_http_request?
      !(@env['HTTP_X_REQUESTED_WITH'] !~ /XMLHttpRequest/i)
    end
    alias xhr? :xml_http_request?

    # Which IP addresses are "trusted proxies" that can be stripped from
    # the right-hand-side of X-Forwarded-For
    TRUSTED_PROXIES = /^127\.0\.0\.1$|^(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\./i

    # Determines originating IP address.  REMOTE_ADDR is the standard
    # but will fail if the user is behind a proxy.  HTTP_CLIENT_IP and/or
    # HTTP_X_FORWARDED_FOR are set by proxies so check for these if
    # REMOTE_ADDR is a proxy.  HTTP_X_FORWARDED_FOR may be a comma-
    # delimited list in the case of multiple chained proxies; the last
    # address which is not trusted is the originating IP.
    def remote_ip
      remote_addr_list = @env['REMOTE_ADDR'] && @env['REMOTE_ADDR'].scan(/[^,\s]+/)

      unless remote_addr_list.blank?
        not_trusted_addrs = remote_addr_list.reject {|addr| addr =~ TRUSTED_PROXIES}
        return not_trusted_addrs.first unless not_trusted_addrs.empty?
      end
      remote_ips = @env['HTTP_X_FORWARDED_FOR'] && @env['HTTP_X_FORWARDED_FOR'].split(',')

      if @env.include? 'HTTP_CLIENT_IP'
        if ActionController::Base.ip_spoofing_check && remote_ips && !remote_ips.include?(@env['HTTP_CLIENT_IP'])
          # We don't know which came from the proxy, and which from the user
          raise ActionControllerError.new(<<EOM)
IP spoofing attack?!
HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect}
HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}
EOM
        end

        return @env['HTTP_CLIENT_IP']
      end

      if remote_ips
        while remote_ips.size > 1 && TRUSTED_PROXIES =~ remote_ips.last.strip
          remote_ips.pop
        end

        return remote_ips.last.strip
      end

      @env['REMOTE_ADDR']
    end

    # Returns the lowercase name of the HTTP server software.
    def server_software
      (@env['SERVER_SOFTWARE'] && /^([a-zA-Z]+)/ =~ @env['SERVER_SOFTWARE']) ? $1.downcase : nil
    end

    # Returns the complete URL used for this request.
    def url
      protocol + host_with_port + request_uri
    end

    # Returns 'https://' if this is an SSL request and 'http://' otherwise.
    def protocol
      ssl? ? 'https://' : 'http://'
    end

    # Is this an SSL request?
    def ssl?
      @env['HTTPS'] == 'on' || @env['HTTP_X_FORWARDED_PROTO'] == 'https'
    end

    # Returns the \host for this request, such as "example.com".
    def raw_host_with_port
      if forwarded = env["HTTP_X_FORWARDED_HOST"]
        forwarded.split(/,\s?/).last
      else
        env['HTTP_HOST'] || "#{env['SERVER_NAME'] || env['SERVER_ADDR']}:#{env['SERVER_PORT']}"
      end
    end

    # Returns the host for this request, such as example.com.
    def host
      raw_host_with_port.sub(/:\d+$/, '')
    end

    # Returns a \host:\port string for this request, such as "example.com" or
    # "example.com:8080".
    def host_with_port
      "#{host}#{port_string}"
    end

    # Returns the port number of this request as an integer.
    def port
      if raw_host_with_port =~ /:(\d+)$/
        $1.to_i
      else
        standard_port
      end
    end

    # Returns the standard \port number for this request's protocol.
    def standard_port
      case protocol
        when 'https://' then 443
        else 80
      end
    end

    # Returns a \port suffix like ":8080" if the \port number of this request
    # is not the default HTTP \port 80 or HTTPS \port 443.
    def port_string
      port == standard_port ? '' : ":#{port}"
    end

    # Returns the \domain part of a \host, such as "rubyonrails.org" in "www.rubyonrails.org". You can specify
    # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
    def domain(tld_length = 1)
      return nil unless named_host?(host)

      host.split('.').last(1 + tld_length).join('.')
    end

    # Returns all the \subdomains as an array, so <tt>["dev", "www"]</tt> would be
    # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
    # such as 2 to catch <tt>["www"]</tt> instead of <tt>["www", "rubyonrails"]</tt>
    # in "www.rubyonrails.co.uk".
    def subdomains(tld_length = 1)
      return [] unless named_host?(host)
      parts = host.split('.')
      parts[0..-(tld_length+2)]
    end

    # Returns the query string, accounting for server idiosyncrasies.
    def query_string
      @env['QUERY_STRING'].present? ? @env['QUERY_STRING'] : (@env['REQUEST_URI'].split('?', 2)[1] || '')
    end

    # Returns the request URI, accounting for server idiosyncrasies.
    # WEBrick includes the full URL. IIS leaves REQUEST_URI blank.
    def request_uri
      if uri = @env['REQUEST_URI']
        # Remove domain, which webrick puts into the request_uri.
        (%r{^\w+\://[^/]+(/.*|$)$} =~ uri) ? $1 : uri
      else
        # Construct IIS missing REQUEST_URI from SCRIPT_NAME and PATH_INFO.
        uri = @env['PATH_INFO'].to_s

        if script_filename = @env['SCRIPT_NAME'].to_s.match(%r{[^/]+$})
          uri = uri.sub(/#{script_filename}\//, '')
        end

        env_qs = @env['QUERY_STRING'].to_s
        uri += "?#{env_qs}" unless env_qs.empty?

        if uri.blank?
          @env.delete('REQUEST_URI')
        else
          @env['REQUEST_URI'] = uri
        end
      end
    end

    # Returns the interpreted \path to requested resource after all the installation
    # directory of this application was taken into account.
    def path
      path = request_uri.to_s[/\A[^\?]*/]
      path.sub!(/\A#{ActionController::Base.relative_url_root}/, '')
      path
    end

    # Read the request \body. This is useful for web services that need to
    # work with raw requests directly.
    def raw_post
      unless @env.include? 'RAW_POST_DATA'
        @env['RAW_POST_DATA'] = body.read(@env['CONTENT_LENGTH'].to_i)
        body.rewind if body.respond_to?(:rewind)
      end
      @env['RAW_POST_DATA']
    end

    # Returns both GET and POST \parameters in a single hash.
    def parameters
      @parameters ||= request_parameters.merge(query_parameters).update(path_parameters).with_indifferent_access
    end
    alias_method :params, :parameters

    def path_parameters=(parameters) #:nodoc:
      @env["action_controller.request.path_parameters"] = parameters
      @symbolized_path_parameters = @parameters = nil
    end

    # The same as <tt>path_parameters</tt> with explicitly symbolized keys.
    def symbolized_path_parameters
      @symbolized_path_parameters ||= path_parameters.symbolize_keys
    end

    # Returns a hash with the \parameters used to form the \path of the request.
    # Returned hash keys are strings:
    #
    #   {'action' => 'my_action', 'controller' => 'my_controller'}
    #
    # See <tt>symbolized_path_parameters</tt> for symbolized keys.
    def path_parameters
      @env["action_controller.request.path_parameters"] ||= {}
    end

    # The request body is an IO input stream. If the RAW_POST_DATA environment
    # variable is already set, wrap it in a StringIO.
    def body
      if raw_post = @env['RAW_POST_DATA']
        raw_post.force_encoding(Encoding::BINARY) if raw_post.respond_to?(:force_encoding)
        StringIO.new(raw_post)
      else
        @env['rack.input']
      end
    end

    def form_data?
      FORM_DATA_MEDIA_TYPES.include?(content_type.to_s)
    end

    # Override Rack's GET method to support indifferent access
    def GET
      @env["action_controller.request.query_parameters"] ||= normalize_parameters(super)
    end
    alias_method :query_parameters, :GET

    # Override Rack's POST method to support indifferent access
    def POST
      @env["action_controller.request.request_parameters"] ||= normalize_parameters(super)
    end
    alias_method :request_parameters, :POST

    def body_stream #:nodoc:
      @env['rack.input']
    end

    def session
      @env['rack.session'] ||= {}
    end

    def session=(session) #:nodoc:
      @env['rack.session'] = session
    end

    def reset_session
      @env['rack.session.options'].delete(:id)
      @env['rack.session'] = {}
    end

    def session_options
      @env['rack.session.options'] ||= {}
    end

    def session_options=(options)
      @env['rack.session.options'] = options
    end

    def server_port
      @env['SERVER_PORT'].to_i
    end

    private
      def named_host?(host)
        !(host.nil? || /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(host))
      end

      # Convert nested Hashs to HashWithIndifferentAccess and replace
      # file upload hashs with UploadedFile objects
      def normalize_parameters(value)
        case value
        when Hash
          if value.has_key?(:tempfile)
            upload = value[:tempfile]
            upload.extend(UploadedFile)
            upload.original_path = value[:filename]
            upload.content_type = value[:type]
            upload
          else
            h = {}
            value.each { |k, v| h[k] = normalize_parameters(v) }
            h.with_indifferent_access
          end
        when Array
          value.map { |e| normalize_parameters(e) }
        else
          value
        end
      end
  end
end
